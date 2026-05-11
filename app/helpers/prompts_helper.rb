module PromptsHelper
	def render_prompt_rich_text(content)
		render_rich_text_markup(content)
	end

	def render_comment_rich_text(content)
		render_rich_text_markup(content, allow_highlights: true)
	end

	def rich_text_plain_text(content)
		strip_tags(legacy_markup_to_html(content.to_s)).gsub(/\u00A0/, ' ').squish
	end

	private

	def render_rich_text_markup(content, allow_highlights: false)
		source = content.to_s.gsub("\r\n", "\n")
		return "".html_safe if source.blank?

		normalized_html = legacy_markup_to_html(source)
		allowed_classes = %w[comment-highlight comment-highlight--green comment-highlight--yellow comment-highlight--red]
		sanitized_html = sanitize(normalized_html, tags: %w[p br strong em ul ol li mark], attributes: %w[class])
		sanitized_html = sanitized_html.gsub(/class="([^"]+)"/) do |match|
			classes = Regexp.last_match(1).split.select { |class_name| allowed_classes.include?(class_name) }
			classes.any? ? %(class="#{classes.join(' ')}") : ''
		end

		if sanitized_html.match?(%r{<(p|ul|ol|li|mark|strong|em|br)\b})
			sanitized_html.html_safe
		else
			simple_format(sanitized_html, { class: 'rich-text-paragraph' }, sanitize: false)
		end
	end

	def legacy_markup_to_html(source)
		return source.to_s if source.to_s.match?(%r{</?(p|br|strong|em|ul|ol|li|mark)\b}i)

		html = ERB::Util.html_escape(source.to_s)
		html = html.gsub(/\[b\](.*?)\[\/b\]/m, '<strong>\\1</strong>')
		html = html.gsub(/\[i\](.*?)\[\/i\]/m, '<em>\\1</em>')
		html = html.gsub(/\[highlight-green\](.*?)\[\/highlight-green\]/m, '<mark class="comment-highlight comment-highlight--green">\\1</mark>')
		html = html.gsub(/\[highlight-yellow\](.*?)\[\/highlight-yellow\]/m, '<mark class="comment-highlight comment-highlight--yellow">\\1</mark>')
		html = html.gsub(/\[highlight-red\](.*?)\[\/highlight-red\]/m, '<mark class="comment-highlight comment-highlight--red">\\1</mark>')
		html = html.gsub(/\[ul\]\s*(.*?)\s*\[\/ul\]/m) { wrap_legacy_list(Regexp.last_match(1), ordered: false) }
		html = html.gsub(/\[ol\]\s*(.*?)\s*\[\/ol\]/m) { wrap_legacy_list(Regexp.last_match(1), ordered: true) }
		html.gsub("\n", "<br>")
	end

	def wrap_legacy_list(body, ordered: false)
		items = body.to_s.split("\n").map(&:strip).reject(&:blank?).map do |line|
			line.sub(/\A(?:[-*]|\d+[.)])\s*/, '')
		end
		return '' if items.empty?

		tag_name = ordered ? 'ol' : 'ul'
		"<#{tag_name}>#{items.map { |item| "<li>#{item}</li>" }.join}</#{tag_name}>"
	end
end
