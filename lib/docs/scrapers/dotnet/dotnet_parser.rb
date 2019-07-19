module Docs
  class DotnetParser
    # A hash containing parsed data about all namespaces, types and members
    # The key is the DocId minus the character in front of the colon and the colon itself
    # The value is the data related to the item identified by the partial DocId in the key
    attr_accessor :data

    # A hash containing the id's of all namespaces.
    attr_accessor :namespaces

    # An array of paths containing types (classes, interfaces, structs, etc.) that need to be parsed
    attr_accessor :type_paths

    # An XPath clause used to select only those nodes that don't include a
    # FrameworkAlternate attribute or where the FrameworkAlternate attribute
    # contains the framework that is currently being scraped
    attr_accessor :framework_alternate_clause

    def initialize(framework_id)
      @framework_alternate_clause = "not(@FrameworkAlternate) or contains(@FrameworkAlternate, '#{framework_id}')"
    end

    DELEGATE_TYPES = %w(Void Int Bool Object String)

    # Parse a file like FrameworksIndex/netcore-2.2.xml
    def parse_index(xml)
      @data = {}
      @namespaces = []
      @type_paths = []

      xml.css('Namespace').each do |namespace_node|
        namespace_name = namespace_node['Name']

        namespace = {
          :name => namespace_name,
          :types => [],
          :classes => [],
          :structs => [],
          :interfaces => [],
          :enums => [],
          :delegates => [],
        }

        @data[namespace_name] = namespace
        @namespaces << namespace_name

        namespace_node.css('Type').each do |type_node|
          type_name = type_node['Id'][2..-1]

          type = {
            :derived => [],
            :fields => [],
            :properties => [],
            :methods => [],
            :operators => [],
            :events => [],
          }

          @data[type_name] = type
          namespace[:types] << type_name

          type_path = type_node['Name'].gsub('/', '+').reverse.sub('.', '/').reverse
          @type_paths << "xml/#{type_path}.xml"

          type_node.css('Member').each do |member_node|
            member_id = member_node['Id']
            member_name = member_id[2..-1]

            member_type_symbol = nil
            case member_id[0]
            when 'F'
              member_type_symbol = :fields
            when 'P'
              member_type_symbol = :properties
            when 'M'
              member_type_symbol = :methods
            when 'E'
              member_type_symbol = :events
            else
              puts "Unknown type '#{member_id[0]}' on member with id '#{member_id}'"
            end

            if member_type_symbol == :methods && member_name.include?('.op_')
              member_type_symbol = :operators
            end

            @data[member_name] = {}
            type[member_type_symbol] << member_name
          end
        end
      end
    end

    # Parse a file like ns-System.xml
    def parse_namespace(xml)
      name = xml.root['Name']

      namespace = @data[name]
      namespace[:path] = name.downcase

      parse_docs(xml, namespace)
    end

    # Parse a file like System/String.xml
    def parse_type(xml)
      id = xml.at_css('TypeSignature[Language="DocId"]')['Value'][2..-1]
      type = @data[id]

      parse_docs(xml.at_css('Type > Docs'), type)

      type[:name] = xml.root['Name'].sub('+', '.')
      type[:path] = xml.root['FullName'].sub('+', '.').downcase

      type[:signatures] = {}
      xml.xpath("//TypeSignature[#{@framework_alternate_clause}]").each do |node|
        type[:signatures][node['Language']] = node['Value'] if node['Language'] != 'DocId'
      end

      type_matches = type[:signatures]['C#'].scan(/([a-z]+) [^a-z]/)
      type[:type] = type_matches[0][0].titleize
      type[:type] = 'Delegate' if DELEGATE_TYPES.include?(type[:type])

      namespace = xml.root['FullName'][0..xml.root['FullName'].size - xml.root['Name'].size - 2]
      namespace = @data[namespace]
      namespace[type_string_to_symbol(type[:type])] << id

      type[:namespace] = xml.root['FullName'].sub(".#{xml.root['Name']}", '')

      type[:assemblies] = {}
      xml.css('Type > AssemblyInfo').each do |node|
        name = node.at_css('AssemblyName').text
        type[:assemblies][name] = node.css('AssemblyVersion').to_a.map(&:text)
      end

      base_node = xml.at_css('BaseTypeName')
      type[:base] = base_node.text unless base_node.nil?

      unless type[:base].nil? or type[:base] == 'System.Object'
        base_id = type[:base]

        # Convert base type names like "System.Lazy<T>" into an id like "System.Lazy`1"
        if base_id.include?('<')
          type_param_count = base_id.scan(/([^<,]+(,|>))/).size
          base_id = "#{base_id.split('<')[0]}`#{type_param_count}"
        end

        @data[base_id][:derived] << id
      end

      type[:interfaces] = xml.css('InterfaceName').to_a.map(&:text)
      type[:attributes] = xml.xpath("/Type/Attributes/Attribute[#{@framework_alternate_clause}]/AttributeName").to_a.map(&:text)
    end

    def parse_docs(node, hash)
      return if node.nil?

      summary = get_text(node.at_css('summary'))
      hash[:summary] = summary unless summary.nil?

      remarks = get_text(node.at_css('remarks'))
      hash[:remarks] = remarks unless remarks.nil?

      thread_safe = get_text(node.at_css('threadsafe'))
      hash[:thread_safe] = thread_safe unless thread_safe.nil?
    end

    def type_string_to_symbol(str)
      case str
      when 'Class'
        :classes
      when 'Struct'
        :structs
      when 'Interface'
        :interfaces
      when 'Enum'
        :enums
      when 'Delegate'
        :delegates
      else
        :unknown
      end
    end

    def get_text(node)
      return nil if node.nil?

      format_node = node.at_css('format')
      node = format_node unless format_node.nil?

      content = CGI.unescape(node.inner_html.strip)
      content != 'To be added.' ? content : nil
    end
  end
end
