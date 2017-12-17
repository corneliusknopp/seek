
module OpenbisHelper

  def can_browse_openbis?(project, user = User.current_user)
    Seek::Config.openbis_enabled && project.has_member?(user) && project.openbis_endpoints.any?
  end

  def modal_openbis_file_view(id)
    modal_options = { id: id, size: 'xl', 'data-role' => 'modal-openbis-file-view' }

    modal_title = 'DataSet Files'

    modal(modal_options) do
      modal_header(modal_title) +
          modal_body do
            content_tag(:div, '', id: :contents)
          end
    end
  end

  def openbis_datafile_dataset(data_file)
    (data_file.external_asset.is_a? OpenbisExternalAsset) ?
        dataset = data_file.external_asset.content :
        dataset = data_file.content_blob.openbis_dataset
    if dataset.error_occurred?
      render partial: 'data_files/openbis/dataset_error'
    else
      #render partial: 'data_files/openbis/dataset', locals: { dataset: dataset, data_file: data_file }
      render partial: 'openbis_datasets/openbis_dataset_panel', locals: { entity: dataset, modal_files: true, edit_button: true }
    end
  end

  def openbis_entity_edit_path(entity)

    if entity.is_a? Seek::Openbis::Zample
      return edit_openbis_endpoint_openbis_zample_path openbis_endpoint_id: entity.openbis_endpoint, id: entity.perm_id
    end
    if entity.is_a? Seek::Openbis::Dataset
      return edit_openbis_endpoint_openbis_dataset_path openbis_endpoint_id: entity.openbis_endpoint, id: entity.perm_id
    end

    'Unsupported'
  end

  def openbis_files_modal_link(dataset)

    openbis_endpoint = dataset.openbis_endpoint
    project = openbis_endpoint.project
    file_count=dataset.dataset_file_count
    files_text = "#{file_count} File".pluralize(file_count)

    link = link_to(files_text, '#', class: 'view-files-link',
                     'data-toggle' => 'modal',
        'data-target' => "#openbis-file-view",
        'data-perm-id' => "#{dataset.perm_id}",
        'data-project-id' => "#{project.id}",
        'data-endpoint-id' => "#{openbis_endpoint.id}")
  end

  class StatefulWordTrimmer

    attr_reader :trimmed

    def initialize(limit)
      @left = limit
      @trimmed = false
    end

    def trim(content)

      return '' if (@trimmed || !content)

      words = []
      content.split(/\s/).each do |w|
        if (@left - w.length) >= 0
          words << w unless w.empty?
          @left -= w.length
        else
          words << '...'
          @trimmed = true
          break
        end
      end
      words.join(' ')
    end

  end

  class TextTrimmingScrubber < Loofah::Scrubber

    def initialize(limit)
      @direction = :top_down
      @trimmer = StatefulWordTrimmer.new(limit)
    end

    def scrub(node)
      if @trimmer.trimmed
        node.remove
        Loofah::Scrubber::STOP
      else
        node.content = @trimmer.trim(node.content) if node.text?
        node
      end
    end

  end

  class StylingScrubber < Loofah::Scrubber

    def initialize
      @direction = :top_down
      @style_attrs = ['class','style']
    end

    def scrub(node)
      node.attribute_nodes.each do |attr_node|
        attr_node.remove if @style_attrs.include? attr_node.node_name
      end
    end

  end

  class ObisXMLScrubber < Loofah::Scrubber

    def initialize
      @direction = :top_down
    end

    def scrub(node)
      case node.name
        when 'commententry' then node.name = 'p'
        when 'root' then node.name = 'div'
      end
    end

  end

  def openbis_rich_content_sanitizer(content, max_length = nil)

    cleaned = Loofah.fragment(content).scrub!(StylingScrubber.new)
    cleaned = cleaned.scrub!(TextTrimmingScrubber.new(max_length)) if max_length
    cleaned = cleaned.scrub!(ObisXMLScrubber.new)
    cleaned.scrub!(:prune).to_s.html_safe

  end
end
