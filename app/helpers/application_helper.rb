require "redcarpet"

module ApplicationHelper
	MARKDOWN_ALLOWED_TAGS = %w[p br div h1 h2 h3 h4 h5 h6 ul ol li strong em a code pre blockquote hr table thead tbody tr th td span u mark].freeze
	MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title rel target class].freeze
	MARKDOWN_ALLOWED_CLASSES = %w[
		help-md-font-sans
		help-md-font-serif
		help-md-font-display
		help-md-font-editorial
		help-md-size-sm
		help-md-size-md
		help-md-size-lg
		help-md-color-slate
		help-md-color-blue
		help-md-color-rose
		help-md-color-emerald
		help-md-highlight
		help-md-highlight--yellow
		help-md-highlight--green
		help-md-highlight--red
	].freeze

	def user_initials(user, fallback: "US")
		user.name.to_s.split.map { |part| part.first }.join.first(2).to_s.upcase.presence || fallback
	end

	def render_markdown(content)
		html = markdown_renderer.render(content.to_s)
		sanitized_html = sanitize(html, tags: MARKDOWN_ALLOWED_TAGS, attributes: MARKDOWN_ALLOWED_ATTRIBUTES)
		sanitized_html = sanitized_html.gsub(/class="([^"]+)"/) do
			classes = Regexp.last_match(1).split.select { |class_name| MARKDOWN_ALLOWED_CLASSES.include?(class_name) }
			classes.any? ? %(class="#{classes.join(' ')}") : ""
		end

		sanitized_html.html_safe
	end

	private

	def markdown_renderer
		@markdown_renderer ||= Redcarpet::Markdown.new(
			Redcarpet::Render::HTML.new(
				filter_html: false,
				hard_wrap: true,
				link_attributes: { rel: "nofollow noopener", target: "_blank" }
			),
			autolink: true,
			fenced_code_blocks: true,
			no_intra_emphasis: true,
			strikethrough: true,
			tables: true,
			underline: true
		)
	end
end
