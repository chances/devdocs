module Docs
  class DotnetFileReader
    include Instrumentable

    ROOT_DIRECTORY = File.expand_path '../../../../../docs/dotnet', __FILE__

    Response = Struct.new :url

    def read_file(path, instrument_before = false, instrument_after = true)
      unless path.start_with?('/')
        path = absolute_path(path)
      end

      if instrument_before
        instrument 'queued.scraper', urls: [path]
      end

      content = File.read(path)
      content = Nokogiri::XML.parse content, nil, 'UTF-8' if path.end_with?('xml')

      if instrument_after
        response = Response.new
        response.url = path
        instrument 'process_response.scraper', response: response
      end

      content
    rescue
      instrument 'warn.doc', msg: "Failed to open file: #{path}"
      nil
    end

    def absolute_path(path)
      if path.start_with?('~/samples/')
        File.join(samples_directory, path.sub!('~/samples/', ''))
      elsif path.start_with?('~/')
        File.join(api_docs_directory, path.sub!('~/', ''))
      else
        File.join(api_docs_directory, path)
      end
    end

    def assert_directories_exist
      unless Dir.exists?(api_docs_directory) and Dir.exists?(samples_directory)
        raise SetupError, "
The .NET scraper requires the following GitHub repositories to be cloned into specific locations:
- https://github.com/dotnet/dotnet-api-docs into #{api_docs_directory}
- https://github.com/dotnet/samples into #{samples_directory}
        ".strip!
      end
    end

    def api_docs_directory
      @api_docs_directory ||= File.join(ROOT_DIRECTORY, 'dotnet-api-docs')
    end

    def samples_directory
      @samples_directory ||= File.join(ROOT_DIRECTORY, 'samples')
    end
  end
end
