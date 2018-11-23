class Person < ApplicationRecord

  acts_as_annotation_source

  include Seek::Rdf::RdfGeneration
  include Seek::Taggable
  include Seek::Roles::AdminDefinedRoles
  include ArTransactionChanges # TODO: Remove after Rails 5.2 upgrade

  auto_strip_attributes :email, :first_name, :last_name, :web_page

  alias_attribute :title, :name

  acts_as_yellow_pages

  scope :default_order, -> { order('last_name, first_name') }

  before_save :first_person_admin_and_add_to_default_project
  before_destroy :clean_up_and_assign_permissions
  after_destroy :updated_contributed_items_contributor_after_destroy

  acts_as_notifiee

  validates_presence_of :email

  validates :email, format: { with: RFC822::EMAIL }
  validates :web_page, url: { allow_nil: true, allow_blank: true }

  validates_uniqueness_of :email, case_sensitive: false

  has_and_belongs_to_many :disciplines

  has_one :user, dependent: :destroy

  has_many :group_memberships, dependent: :destroy, inverse_of: :person
  has_many :work_groups, through: :group_memberships, inverse_of: :people

  has_many :former_group_memberships, -> { where('time_left_at IS NOT NULL AND time_left_at <= ?', Time.now) },
           class_name: 'GroupMembership', dependent: :destroy
  has_many :former_work_groups, class_name: 'WorkGroup', through: :former_group_memberships,
                                source: :work_group

  has_many :current_group_memberships, -> { where('time_left_at IS NULL OR time_left_at > ?', Time.now) },
           class_name: 'GroupMembership', dependent: :destroy
  has_many :current_work_groups, class_name: 'WorkGroup', through: :current_group_memberships,
                                 source: :work_group

  has_many :institutions, -> { distinct }, through: :work_groups

  has_many :favourite_group_memberships, dependent: :destroy
  has_many :favourite_groups, through: :favourite_group_memberships

  has_many :assets_creators, dependent: :destroy, foreign_key: 'creator_id'

  RELATED_RESOURCE_TYPES = %w[DataFile Sop Model Document Publication Presentation
                              Sample Event Investigation Study Assay Strain].freeze

  RELATED_RESOURCE_TYPES.each do |type|
    has_many :"contributed_#{type.tableize}", foreign_key: :contributor_id, class_name: type
    has_many :"created_#{type.tableize}", through: :assets_creators, source: :asset, source_type: type
  end

  RELATED_RESOURCE_TYPES.collect(&:tableize).each do |type|
    define_method "related_#{type}" do
      send("created_#{type}") | send("contributed_#{type}")
    end
  end


  has_annotation_type :expertise, method_name: :expertise
  has_annotation_type :tool

  has_many :publication_authors

  if Seek::Config.solr_enabled
    searchable(auto_index: false) do
      text :project_positions
      text :disciplines do
        disciplines.map(&:title)
      end
    end
  end

  scope :with_group, -> { includes(:group_memberships).where('group_memberships.person_id IS NOT NULL').references(:group_memberships) }
  scope :without_group, -> { includes(:group_memberships).where('group_memberships.person_id IS NULL').references(:group_memberships) }
  scope :registered, -> { includes(:user).where('users.person_id != 0').references(:users) }
  scope :not_registered, -> { includes(:user).where('users.person_id IS NULL').references(:users) }

  alias_attribute :webpage, :web_page

  include Seek::Subscriptions::PersonProjectSubscriptions
  include Seek::OrcidSupport

  after_commit :queue_update_auth_table

  after_destroy :update_publication_authors_after_destroy
  
  # to make it look like a User
  def person
    self
  end    

  # not registered profiles that match this email
  def self.not_registered_with_matching_email(email)
    not_registered.where('UPPER(email) = ?', email.upcase)
  end

  def queue_update_auth_table
    if transaction_changed_attributes.keys.include?('roles_mask')
      AuthLookupUpdateJob.new.add_items_to_queue self
    end
  end

  def projects_with_default_license
    projects.select(&:default_license)
  end

  # those that have updated time stamps and avatars appear first. A future enhancement could be to judge activity by last asset updated timestamp
  def self.active
    Person.unscoped.order('avatar_id DESC, updated_at DESC')
  end

  def receive_notifications
    member? && super
  end

  def registered?
    !user.nil?
  end

  def email_uri
    URI.escape('mailto:' + email)
  end

  def mbox_sha1sum
    Digest::SHA1.hexdigest(email_uri)
  end

  # only partially shows the email, to allow it to be used to know you are selected the right person, but without revealing the full address
  def obfuscated_email
    email.gsub(/.*\@/,'....@')
  end

  def typeahead_hint
    if projects.any?
      projects.collect(&:title).join(', ')
    else
      obfuscated_email
    end
  end

  def programmes
    projects.collect(&:programme).uniq
  end

  # whether this person belongs to a programme in common with the other item - generally a person or project
  def shares_programme?(other_item)
    (programmes & other_item.programmes).any?
  end

  # whether this person belongs to a project in common with the other item - whcih can eb a person, project or enumeration of projects
  def shares_project?(other_item)
    projects = if other_item.is_a?(Project) || other_item.is_a?(Enumerable)
                 Array(other_item)
               else
                 other_item.projects
               end

    (self.projects & projects).any?
  end

  def shares_project_or_programme?(other_item)
    shares_project?(other_item) || shares_programme?(other_item)
  end




  def self.userless_people
    Person.includes(:user).select { |p| p.user.nil? }
  end

  # returns an array of Person's where the first and last name match
  def self.duplicates
    people = Person.all
    dup = []
    people.each do |p|
      peeps = people.select { |p2| p.name == p2.name }
      dup |= peeps if peeps.count > 1
    end
    dup
  end

  def cache_key
    groups = group_memberships.compact.collect { |gm| gm.id.to_s }.join('.')
    progs = programmes.compact.collect { |pg| pg.id.to_s }.join('.')
    "#{super}-#{groups}-#{progs}"
  end

  # get a list of people with their email for autocomplete fields
  def self.get_all_as_json
    Person.order('ID asc').collect do |p|
      { 'id' => p.id, 'name' => p.name, 'email' => p.email, 'projects' => p.projects.collect(&:title).join(', ') }
    end.to_json
  end

  def validates_associated(*associations)
    associations.each do |_association|
      class_eval do
        validates_each(associations) do |record, associate_name, _value|
          associates = record.send(associate_name)
          associates = [associates] unless associates.respond_to?('each')
          associates.each do |associate|
            next unless associate && !associate.valid?
            associate.errors.each do |key, value|
              record.errors.add(key, value)
            end
          end
        end
      end
    end
  end

  def projects # ALL projects, former and current
    # updating workgroups doesn't change groupmemberships until you save. And vice versa.
    work_groups.collect(&:project).uniq | group_memberships.collect { |gm| gm.work_group.project }
  end

  def current_projects
    (current_work_groups.collect(&:project).uniq | current_group_memberships.collect { |gm| gm.work_group.project })
  end

  # Projects that the person has let completely (i.e. not still involved with through a different institution)
  def former_projects
    old_projects = (former_work_groups.collect(&:project).uniq | former_group_memberships.collect { |gm| gm.work_group.project })

    old_projects - current_projects
  end

  def member?
    projects.any?
  end

  def member_of?(item_or_array)
    !(Array(item_or_array) & projects).empty?
  end

  def locations
    # infer all person's locations from the institutions where the person is member of
    institutions.collect(&:country).compact.uniq
  end

  def email_with_name
    name + ' <' + email + '>'
  end

  def name
    firstname = first_name || ''
    lastname = last_name || ''
    # capitalize, including double barrelled names
    # TODO: why not just store them like this rather than processing each time? Will need to reprocess exiting entries if we do this.
    (firstname.gsub(/\b\w/, &:upcase) + ' ' + lastname.gsub(/\b\w/, &:upcase)).strip
  end

  # returns true this is an admin person, and they are the only one defined - indicating they are person creating during setting up SEEK
  def only_first_admin_person?
    Person.count == 1 && [self] == Person.all && Person.first.is_admin?
  end

  def project_positions
    project_positions = []
    group_memberships.each do |gm|
      project_positions |= gm.project_positions
    end
    project_positions
  end

  def update_first_letter
    no_last_name = last_name.nil? || last_name.strip.blank?
    first_letter = strip_first_letter(last_name) unless no_last_name
    first_letter = strip_first_letter(name) if no_last_name
    # first_letter = "Other" unless ("A".."Z").to_a.include?(first_letter)
    self.first_letter = first_letter
  end

  def project_positions_of_project(projects_or_project)
    # Get intersection of all project memberships + person's memberships to find project membership
    projects_or_project = Array(projects_or_project)
    memberships = group_memberships.select { |g| projects_or_project.include? g.work_group.project }
    memberships.collect(&:project_positions).flatten
  end

  # all items, assets, ISA and samples that are linked to this person as a creator
  def created_items
    assets_creators.map(&:asset).uniq.compact
  end

  # all items, assets, ISA, samples and events that are linked to this person as a contributor
  def contributed_items
    [Assay, Study, Investigation, DataFile, Document, Sop, Presentation, Model, Sample, Strain, Publication, Event, SampleType].collect do |type|
      type.where(contributor_id:id)
    end.flatten.uniq.compact
  end

  # can be edited by:
  # (admin or project managers of this person) and (this person does not have a user or not the other admin)
  # themself
  def can_be_edited_by?(user)
    return false unless user
    user = user.user if user.is_a?(Person)
    (user == self.user) || user.is_admin? || (is_project_administered_by?(user) && self.user.nil?)
  end

  def me?
    user && user == User.current_user
  end

  # admin can administer other people, project manager can administer other people except other admins and themself
  def can_be_administered_by?(user)
    person = user.is_a?(User) ? user.person : user
    return false unless user && person
    is_proj_or_prog_admin = person.is_project_administrator_of_any_project? || person.is_programme_administrator_of_any_programme?
    user.is_admin? || (is_proj_or_prog_admin && (is_admin? || self != person))
  end

  def can_view?(user = User.current_user)
    !user.nil? || !Seek::Config.is_virtualliver
  end

  def can_edit?(user = User.current_user)
    new_record? || can_be_edited_by?(user)
  end

  def can_manage?(user = User.current_user)
    user.try(:is_admin?)
  end

  def can_delete?(user = User.current_user)
    can_manage? user
  end

  def title_is_public?
    true
  end

  def recent_activity(limit = 10)
    # TODO: Need to find a better way of doing this
    results = ActivityLog.group(:id, :activity_loggable_type, :activity_loggable_id)
                         .where(culprit_type: 'User', culprit_id: user, action: 'update')
                         .where('controller_name != \'sessions\'')
                         .where('controller_name != \'people\'')
                         .order('created_at DESC')
                         .limit(limit)
                         .distinct +
              ActivityLog.group(:id, :activity_loggable_type, :activity_loggable_id)
              .where(culprit_type: 'User', culprit_id: user, action: 'create')
              .where('controller_name != \'sessions\'')
              .where('controller_name != \'people\'')
              .order('created_at DESC')
              .limit(limit)
              .distinct
    results.sort_by(&:created_at).reverse.uniq { |r| "#{r.activity_loggable_type}#{r.activity_loggable_id}" }[0...limit]
  end

  def recent_items(limit = 10)
    recent_activity(limit).map(&:activity_loggable)
  end

  # remove the permissions which are set on this person
  def remove_permissions
    permissions = Permission.where(['contributor_type =? and contributor_id=?', 'Person', id])
    permissions.each(&:destroy)
  end

  def clean_up_and_assign_permissions
    # remove the permissions which are set on this person
    remove_permissions

    # retrieve the items that this person is contributor (owner for assay), and that also has policy authorization
    person_related_items = contributed_items.select{|item| item.respond_to?(:policy)}

    # check if anyone has manage right on the related_items
    # if not or if only the contributor then assign the manage right to pis||pals
    person_related_items.each do |item|
      people_can_manage_item = item.people_can_manage
      next unless people_can_manage_item.blank? || (people_can_manage_item == [[id, name.to_s, Policy::MANAGING]])
      # find the projects which this person and item belong to
      projects_in_common = projects & item.projects
      pis = projects_in_common.collect(&:pis).flatten.uniq
      pis.reject! { |pi| pi.id == id }
      policy = item.policy
      if pis.blank?
        pals = projects_in_common.collect(&:pals).flatten.uniq
        pals.reject! { |pal| pal.id == id }
        pals.each do |pal|
          policy.permissions.build(contributor: pal, access_type: Policy::MANAGING)
          policy.save
        end
      else
        pis.each do |pi|
          policy.permissions.build(contributor: pi, access_type: Policy::MANAGING)
          policy.save
        end
      end
    end
  end

  # a utitlity method to simply add a person to a project and institution
  # will automatically handle the WorkGroup and GroupMembership, and avoid creating duplicates
  def add_to_project_and_institution(project, institution)
    group = WorkGroup.where(project_id: project.id, institution_id: institution.id).first
    group ||= WorkGroup.new project: project, institution: institution

    membership = GroupMembership.where(person_id: id, work_group_id: group.id).first
    membership ||= GroupMembership.new person: self, work_group: group

    group_memberships << membership
  end

  private

  # a before_save trigger, that checks if the person is the first one created, and if so defines it as admin
  def first_person_admin_and_add_to_default_project
    if Person.count.zero?
      self.is_admin = true
      project = Project.first
      if project && project.institutions.any?
        add_to_project_and_institution(project, project.institutions.first)
      end
    end
  end

  def self.can_create?
    User.admin_or_project_administrator_logged_in? ||
      User.activated_programme_administrator_logged_in? ||
      (User.logged_in? && !User.current_user.registration_complete?)
  end

  #replaces the author names with those of the deleted person
  def update_publication_authors_after_destroy
    publication_authors.each do |author|
      author.update_attribute(:last_name,self.last_name)
      author.update_attribute(:first_name,self.first_name)
    end
  end

  def updated_contributed_items_contributor_after_destroy
    contributed_items.each do |item|
      item.update_column(:contributor_id,nil)
      item.update_column(:deleted_contributor,"Person:#{id}")
      if item.respond_to?(:versions)
        item.versions.select{|v| v.contributor_id==id}.each do |v|
          v.update_column(:contributor_id,nil)
          v.update_column(:deleted_contributor,"Person:#{id}")
        end
      end
    end
  end

  include Seek::ProjectHierarchies::PersonExtension if Seek::Config.project_hierarchy_enabled
end
