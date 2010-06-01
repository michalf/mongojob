module MongoJob::WebHelpers
  def versioned_css(stylesheet)
    # Check for css and sass files
    css_file = File.join(MongoJob::Web.public,"style", "#{stylesheet}.css")
    sass_file = File.join(MongoJob::Web.views,"style", "#{stylesheet}.sass")

    if File.exists? css_file
      mtime = File.mtime(css_file).to_i.to_s
    else
      if File.exists? sass_file
        mtime = File.mtime(sass_file).to_i.to_s
      end
    end
    mime ||= '0'
    "/style/#{stylesheet}.css?" + mtime
  end
  def versioned_js(js)
    "/script/#{js}.js?" + File.mtime(File.join(MongoJob::Web.public, "script", "#{js}.js")).to_i.to_s
  end

  def versioned_resource(resource)
    "/#{resource}?" + File.mtime(File.join(MongoJob::Web.public, resource)).to_i.to_s
  end

  def request_uri
    request.env["REQUEST_URI"]
  end
end

# Copied and adapted to HAML from http://gist.github.com/119874 - thanks!
module Sinatra::Partials
  def partial(template, *args)
    template_array = template.to_s.split('/')
    template = template_array[0..-2].join('/') + "/_#{template_array[-1]}"
    options = args.last.is_a?(Hash) ? args.pop : {}
    options.merge!(:layout => false)
    if collection = options.delete(:collection) then
      collection.inject([]) do |buffer, member|
        buffer << haml(:"#{template}", options.merge(:layout =>
        false, :locals => {template_array[-1].to_sym => member}))
      end.join("\n")
    else
      haml(:"#{template}", options)
    end
  end
end