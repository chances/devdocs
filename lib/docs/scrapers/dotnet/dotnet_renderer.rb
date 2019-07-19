module Docs
  class DotnetRenderer
    def initialize(scraper, parser, file_reader)
      @scraper = scraper
      @parser = parser
      @file_reader = file_reader
    end

    def render_index
      render(INDEX_PAGE_ERB)
    end

    def render_namespace(namespace)
      render(NAMESPACE_PAGE_ERB, {:namespace => namespace})
    end

    def render_type(type)
      render(TYPE_PAGE_ERB, {:type => type})
    end

    def render_table(type, items)
      return '' if items.empty?
      render(TABLE_ERB, {:type => type, :items => items})
    end

    def render_attribution(path)
      link = "https://docs.microsoft.com/en-us/dotnet/api/#{path}?view=#{@scraper.framework_id}"
      render(ATTRIBUTION_ERB, {:link => link})
    end

    def render(template, extra_data = {})
      data = binding
      data.local_variable_set(:scraper, @scraper)
      data.local_variable_set(:parser, @parser)

      extra_data.keys.each do |key|
        data.local_variable_set(key, extra_data[key])
      end

      ERB.new(template).result(data)
    end

    def format(text)
      return '' if text.nil?

      text.gsub!(/<see cref="([^"]+)"><\/see>/) do |m|
        id = $1[2..-1]
        data = @parser.data[id]

        if data.nil?
          "<a href=\"https://docs.microsoft.com/en-us/dotnet/api/#{id.downcase}?view=#{@scraper.framework_id}\">#{id}</a>"
        else
          "<a href=\"#{data[:path]}\">#{escape data[:name]}</a>"
        end
      end

      text
    end

    def escape(text)
      text.nil? ? '' : CGI.escape_html(text)
    end

    def singular_to_plural(singular)
      suffix = singular.end_with?('s') ? 'es' : 's'
      singular + suffix
    end

    INDEX_PAGE_ERB = <<-HTML.strip_heredoc
      <h1><%= scraper.framework_name %></h1>

      <%= render_table 'Namespace', parser.namespaces.map {|id| parser.data[id]} %>

      <%= render_attribution '' %>
    HTML

    NAMESPACE_PAGE_ERB = <<-HTML.strip_heredoc
      <h1><%= namespace[:name] %></h1>

      <%= render_table 'Class', namespace[:classes].map {|id| parser.data[id]} %>
      <%= render_table 'Struct', namespace[:structs].map {|id| parser.data[id]} %>
      <%= render_table 'Interface', namespace[:interfaces].map {|id| parser.data[id]} %>
      <%= render_table 'Enum', namespace[:enums].map {|id| parser.data[id]} %>
      <%= render_table 'Delegate', namespace[:delegates].map {|id| parser.data[id]} %>

      <%= render_attribution namespace[:path] %>
    HTML

    TYPE_PAGE_ERB = <<-HTML.strip_heredoc
      <h1><%= escape type[:name] %></h1>
    HTML

    TABLE_ERB = <<-HTML.strip_heredoc
      <table>
        <caption><%= singular_to_plural type %></caption>
        <thead>
          <tr>
            <th><%= type %></th>
            <th>Summary</th>
          </tr>
        </thead>
        <tbody>
          <% items.each do |item| %>
          <tr>
            <td><a href="<%= item[:path] %>"><%= escape item[:name] %></a></td>
            <td><%= format item[:summary] %></td>
          </tr>
          <% end %>
        </tbody>
      </table>
    HTML

    PAGE_ERB = <<-HTML.strip_heredoc
      Entry
    HTML

    ATTRIBUTION_ERB = <<-HTML.strip_heredoc
      <div class="_attribution">
        <p class="_attribution-p">
          &copy; .NET Foundation and contributors<br>
          Documentation is licensed under the Creative Commons Attribution 4.0 International License.<br>
          Code snippets are licensed under the MIT license.<br>
          <a href="<%= link %>" class="_attribution-link"><%= link %></a>
        </p>
      </div>
    HTML
  end
end
