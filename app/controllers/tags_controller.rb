class TagsController < ApplicationController
  before_filter :find_tag, only: [:show]
  before_filter :find_tagged_objects, only: [:show]

  def show
    if @tagged_objects.empty?
      flash.now[:notice] = "No objects (or none that you are authorized to view) are tagged with '<b>#{h(@tag.text)}</b>'.".html_safe
    else
      flash.now[:notice] = "#{@tagged_objects.size} #{'item'.pluralize(@tagged_objects.size)} tagged with '<b>#{h(@tag.text)}</b>'.".html_safe
    end
    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def index
    respond_to do |format|
      format.html
    end
  end

  def latest
    tags = get_tags
    @tags = tags ? get_tags.limit(params[:limit] || 50).map(&:text) : []
    respond_to do |format|
      format.json { render json: @tags.to_json }
    end
  end

  def query
    @tags = get_tags.where('text LIKE ?', "#{params[:query]}%").limit(20).map(&:text)
    respond_to do |format|
      format.json { render json: @tags.to_json }
    end
  end

  private

  def find_tag
    @tag = TextValue.find_by_id(params[:id])
    unless @tag
      flash[:error] = 'The Tag does not exist'
      respond_to do |format|
        format.html { redirect_to all_anns_path }
        format.xml { head status: 404 }
      end
    end
  end

  def find_tagged_objects
    types = tag_types_for_selection
    objects = @tag.annotations.with_attribute_name(types).collect(&:annotatable).uniq
    @tagged_objects = select_authorised(objects)
  end

  def tag_types_for_selection
    if params[:type]
      types = [params[:type]]
    else
      types = %w(expertise tool tag sample_type_tags)
    end
    types
  end

  # Removes all results from the search results collection passed in that are not Authorised to show for the current_user
  def select_authorised(collection)
    collection.select(&:can_view?)
  end

  def get_tags
    attribute = AnnotationAttribute.where(name: params[:type] || 'tag').first
    TextValue.select(:text)
      .joins("LEFT OUTER JOIN annotations ON annotations.value_id = text_values.id AND annotations.value_type = 'TextValue'" \
                  'LEFT OUTER JOIN annotation_value_seeds ON annotation_value_seeds.value_id = text_values.id')
      .where('annotations.attribute_id = :attribute_id OR annotation_value_seeds.attribute_id = :attribute_id', attribute_id: attribute.try(:id)).uniq
  end
end