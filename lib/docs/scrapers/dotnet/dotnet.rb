module Docs
  class Dotnet < Doc
    include Instrumentable

    class << self
      attr_accessor :framework_id

      def inherited(subclass)
        super
        subclass.framework_id = framework_id
      end
    end

    # Instructions
    #
    # Clone the following GitHub repositories into their given location:
    # - https://github.com/dotnet/dotnet-api-docs into docs/dotnet/dotnet-api-docs
    # - https://github.com/dotnet/samples into docs/dotnet/samples
    #
    # self.framework_id is any of the filenames in docs/dotnet/dotnet-api-docs/xml/FrameworksIndex without it's extension

    self.name = '.NET'
    self.slug = 'dotnet'
    self.type = 'simple'

    version 'Core' do
      self.release = '2.2'
      self.framework_id = 'netcore-2.2'

      self.links = {
        home: 'https://docs.microsoft.com/en-us/dotnet/api/?view=netcore-2.2',
        code: 'https://github.com/dotnet/corefx',
      }
    end

    version 'Framework' do
      self.release = '4.8'
      self.framework_id = 'netframework-4.8'

      self.links = {
        home: 'https://docs.microsoft.com/en-us/dotnet/api/?view=netframework-4.8',
        code: 'https://github.com/microsoft/referencesource',
      }
    end

    def build_pages
      file_reader = DotnetFileReader.new
      file_reader.assert_directories_exist

      parser = DotnetParser.new(framework_id)
      renderer = DotnetRenderer.new(self, parser, file_reader)

      index_path = "xml/FrameworksIndex/#{framework_id}.xml"
      instrument 'running.scraper', urls: [index_path]

      index_xml = file_reader.read_file(index_path)
      parser.parse_index(index_xml)

      namespace_paths = parser.namespaces.map {|namespace| "xml/ns-#{parser.data[namespace][:name]}.xml"}

      instrument 'queued.scraper', urls: namespace_paths + parser.type_paths

      namespace_paths.each do |namespace_path|
        namespace_xml = file_reader.read_file(namespace_path)
        parser.parse_namespace(namespace_xml)
      end

      parser.type_paths.each do |type_path|
        type_xml = file_reader.read_file(type_path)
        parser.parse_type(type_xml)
      end

      index_page = {
        path: 'index',
        store_path: 'index.html',
        output: renderer.render_index,
        entries: [Entry.new(nil, 'index', nil)]
      }

      yield index_page

      parser.namespaces.each do |namespace_name|
        namespace = parser.data[namespace_name]

        namespace_page = {
          path: namespace[:path],
          store_path: namespace[:path] + '.html',
          output: renderer.render_namespace(namespace),
          entries: [Entry.new(namespace[:name], namespace[:path], '# Namespaces')],
        }

        yield namespace_page

        namespace[:types].each do |type_name|
          type = parser.data[type_name]

          type_page = {
            path: type[:path],
            store_path: type[:path] + '.html',
            output: renderer.render_type(type),
            entries: [Entry.new(type[:name], type[:path], namespace[:name])],
          }

          yield type_page
        end
      end
    end

    def framework_id
      self.class.framework_id || raise('framework_id is required')
    end

    def framework_name
      @framework_name ||= "#{self.class.name} #{self.class.version} #{self.class.release}"
    end
  end
end
