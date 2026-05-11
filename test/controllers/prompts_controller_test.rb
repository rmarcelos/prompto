require "test_helper"

class PromptsControllerTest < ActionDispatch::IntegrationTest
  test "index renders ranking section before filters" do
    user = User.create!(
      email: "prompt-ranking-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Ranking User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Ranking #{SecureRandom.hex(4)}",
      color: "#445566",
      creator: user,
      updater: user
    )

    Prompt.create!(
      title: "Prompt ranking base",
      description: "Descricao ranking",
      content: "Conteudo ranking",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get prompts_path

    assert_response :success
    assert_includes response.body, I18n.t('prompts.index.ranking.title')
    assert_includes response.body, I18n.t('prompts.index.ranking.metrics.most_liked.label')
    assert_operator response.body.index(I18n.t('prompts.index.ranking.title')), :<, response.body.index('class="profile-prompt-filters p-4 mb-4"')
  end

  test "index ranking orders users by likes received" do
    leading_user = User.create!(
      email: "prompt-ranking-leading-#{SecureRandom.hex(4)}@example.com",
      name: "Ranking Lider",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    trailing_user = User.create!(
      email: "prompt-ranking-trailing-#{SecureRandom.hex(4)}@example.com",
      name: "Ranking Vice",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    fan_one = User.create!(
      email: "prompt-ranking-fan-one-#{SecureRandom.hex(4)}@example.com",
      name: "Ranking Fan One",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    fan_two = User.create!(
      email: "prompt-ranking-fan-two-#{SecureRandom.hex(4)}@example.com",
      name: "Ranking Fan Two",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Ranking Likes #{SecureRandom.hex(4)}",
      color: "#556677",
      creator: leading_user,
      updater: leading_user
    )

    leading_prompt = Prompt.create!(
      title: "Prompt lider ranking",
      description: "Descricao lider",
      content: "Conteudo lider",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: leading_user,
      updater: leading_user
    )

    trailing_prompt = Prompt.create!(
      title: "Prompt vice ranking",
      description: "Descricao vice",
      content: "Conteudo vice",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: trailing_user,
      updater: trailing_user
    )

    Favorite.create!(user: fan_one, prompt: leading_prompt)
    Favorite.create!(user: fan_two, prompt: leading_prompt)
    Favorite.create!(user: fan_one, prompt: trailing_prompt)

    post login_path, params: {
      session: {
        email: fan_one.email,
        password: "123456"
      }
    }

    get prompts_path, params: { ranking_period: 'general', ranking_metric: 'most_liked' }

    assert_response :success
    assert_operator response.body.index(leading_user.name), :<, response.body.index(trailing_user.name)
  end

  test "index ranking shows at most the top three users" do
    users = 4.times.map do |index|
      User.create!(
        email: "prompt-ranking-top-#{index}-#{SecureRandom.hex(3)}@example.com",
        name: "Ranking Top #{index + 1}",
        role: "user",
        password: "123456",
        password_confirmation: "123456"
      )
    end

    fans = 4.times.map do |index|
      User.create!(
        email: "prompt-ranking-fan-#{index}-#{SecureRandom.hex(3)}@example.com",
        name: "Ranking Fan #{index + 1}",
        role: "user",
        password: "123456",
        password_confirmation: "123456"
      )
    end

    category = Category.create!(
      name: "Categoria Ranking Top #{SecureRandom.hex(4)}",
      color: "#7788AA",
      creator: users.first,
      updater: users.first
    )

    users.each_with_index do |user, index|
      prompt = Prompt.create!(
        title: "Prompt ranking top #{index + 1}",
        description: "Descricao ranking top #{index + 1}",
        content: "Conteudo ranking top #{index + 1}",
        category: category,
        visibility: "public",
        is_anonymous: false,
        creator: user,
        updater: user
      )

      fans.first(4 - index).each do |fan|
        Favorite.create!(user: fan, prompt: prompt)
      end
    end

    post login_path, params: {
      session: {
        email: fans.first.email,
        password: "123456"
      }
    }

    get prompts_path, params: { ranking_period: 'general', ranking_metric: 'most_liked' }

    assert_response :success
    ranking_section = response.body[/<section class="prompts-ranking-card.*?<\/section>/m]

    assert_not_nil ranking_section
    assert_equal 3, ranking_section.scan('class="d-flex prompts-ranking-row"').count
    assert_includes ranking_section, users[0].name
    assert_includes ranking_section, users[1].name
    assert_includes ranking_section, users[2].name
    assert_not_includes ranking_section, users[3].name
  end

  test "index renders prompt filter bar with search and order controls" do
    user = User.create!(
      email: "prompt-index-filter-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Index Filter User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Filter #{SecureRandom.hex(4)}",
      color: "#556677",
      creator: user,
      updater: user
    )

    Prompt.create!(
      title: "Prompt com filtro",
      description: "Descricao filtro",
      content: "Conteudo filtro",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get prompts_path

    assert_response :success
    assert_includes response.body, 'class="profile-prompt-filters p-4 mb-4"'
    assert_includes response.body, 'name="search_in"'
    assert_includes response.body, 'name="query"'
    assert_includes response.body, 'name="order_by"'
    assert_includes response.body, I18n.t('prompts.index.filters.categories.label')
    assert_includes response.body, I18n.t('prompts.index.filters.order.options.most_liked')
  end

  test "index renders favorite form for other users prompts and filled heart for owners prompts" do
    user = User.create!(
      email: "prompt-index-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Index User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    other_user = User.create!(
      email: "prompt-index-other-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Index Other",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    own_category = Category.create!(
      name: "Categoria Index Propria #{SecureRandom.hex(4)}",
      color: "#335577",
      creator: user,
      updater: user
    )

    other_category = Category.create!(
      name: "Categoria Index Outra #{SecureRandom.hex(4)}",
      color: "#557799",
      creator: other_user,
      updater: other_user
    )

    own_prompt = Prompt.create!(
      title: "Prompt proprio no indice",
      description: "Descricao propria no indice",
      content: "Conteudo proprio no indice",
      category: own_category,
      visibility: "public",
      is_anonymous: true,
      creator: user,
      updater: user
    )

    other_prompt = Prompt.create!(
      title: "Prompt de outro no indice",
      description: "Descricao de outro no indice",
      content: "Conteudo de outro no indice",
      category: other_category,
      visibility: "public",
      is_anonymous: false,
      creator: other_user,
      updater: other_user
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get prompts_path

    assert_response :success
    assert_includes response.body, "action=\"#{prompt_favorite_path(other_prompt)}\""
    assert_includes response.body, 'data-prompt-card-favorite-form="true"'
    assert_match(/bi-heart-fill heart-icon.*Prompt proprio no indice/m, response.body)
    assert_not_includes response.body, "action=\"#{prompt_favorite_path(own_prompt)}\""
    assert_includes response.body, I18n.t('prompts.card.footer.created_by', author: I18n.t('prompts.card.footer.author_self'))
  end

  test "index renders profile links on ranking and prompt author names" do
    user = User.create!(
      email: "prompt-index-link-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Link User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    viewer = User.create!(
      email: "prompt-index-link-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Link Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Links #{SecureRandom.hex(4)}",
      color: "#445566",
      creator: user,
      updater: user
    )

    prompt = Prompt.create!(
      title: "Prompt com autor clicavel",
      description: "Descricao com autor clicavel",
      content: "Conteudo com autor clicavel",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    Favorite.create!(user: viewer, prompt: prompt)

    post login_path, params: {
      session: {
        email: viewer.email,
        password: "123456"
      }
    }

    get prompts_path

    assert_response :success
    assert_match %r{<a[^>]*class="prompts-ranking-user-name prompts-ranking-user-link"[^>]*href="#{Regexp.escape(user_path(user))}"[^>]*>#{Regexp.escape(user.name)}</a>}, response.body
    assert_match %r{<a[^>]*class="card-author-link"[^>]*href="#{Regexp.escape(user_path(user))}"[^>]*>#{Regexp.escape(user.name)}</a>}, response.body
  end

  test "index paginates prompts with ten items per page and preserves filter params in navigation" do
    user = User.create!(
      email: "prompt-pagination-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Pagination User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Paginacao #{SecureRandom.hex(4)}",
      color: "#667788",
      creator: user,
      updater: user
    )

    12.times do |index|
      Prompt.create!(
        title: "Prompt paginado #{index + 1}",
        description: "Descricao paginada #{index + 1}",
        content: "Conteudo paginado #{index + 1}",
        category: category,
        visibility: "public",
        is_anonymous: false,
        creator: user,
        updater: user
      )
    end

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get prompts_path, params: { query: 'Prompt paginado', search_in: 'title', order_by: 'recent' }

    assert_response :success
    assert_select 'nav.app-pagination-nav'
    assert_select 'nav.app-pagination-nav ul.pagination.justify-content-end'
    assert_select 'div.col-12.col-lg-6', 10
    assert_includes response.body, I18n.t('shared.pagination.previous')
    assert_includes response.body, I18n.t('shared.pagination.next')
    assert_includes response.body, I18n.t('shared.pagination.last')
    assert_includes response.body, ERB::Util.html_escape(prompts_path(query: 'Prompt paginado', search_in: 'title', order_by: 'recent', page: 2))

    get prompts_path, params: { query: 'Prompt paginado', search_in: 'title', order_by: 'recent', page: 2 }

    assert_response :success
    assert_select 'div.col-12.col-lg-6', 2
    assert_includes response.body, 'Prompt paginado 1'
    assert_includes response.body, 'Prompt paginado 2'
  end

  test "index filters prompts by title query and orders by most liked" do
    user = User.create!(
      email: "prompt-index-search-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Index Search User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    fan_one = User.create!(
      email: "prompt-index-fan-one-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Index Fan One",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    fan_two = User.create!(
      email: "prompt-index-fan-two-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Index Fan Two",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Search #{SecureRandom.hex(4)}",
      color: "#667788",
      creator: user,
      updater: user
    )

    most_liked_prompt = Prompt.create!(
      title: "Prompt buscado mais curtido",
      description: "Descricao buscada",
      content: "Conteudo buscado",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    less_liked_prompt = Prompt.create!(
      title: "Prompt buscado menos curtido",
      description: "Outra descricao buscada",
      content: "Outro conteudo buscado",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    Prompt.create!(
      title: "Prompt fora da busca",
      description: "Descricao fora",
      content: "Conteudo fora",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    Favorite.create!(user: fan_one, prompt: most_liked_prompt)
    Favorite.create!(user: fan_two, prompt: most_liked_prompt)
    Favorite.create!(user: fan_one, prompt: less_liked_prompt)

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get prompts_path, params: { query: 'buscado', search_in: 'title', order_by: 'most_liked' }

    assert_response :success
    assert_includes response.body, most_liked_prompt.title
    assert_includes response.body, less_liked_prompt.title
    assert_not_includes response.body, 'Prompt fora da busca'
    assert_operator response.body.index(most_liked_prompt.title), :<, response.body.index(less_liked_prompt.title)
  end

  test "index filters prompts by category while preserving search params" do
    user = User.create!(
      email: "prompt-index-category-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Index Category User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    primary_category = Category.create!(
      name: "Categoria Primaria #{SecureRandom.hex(4)}",
      color: "#778899",
      creator: user,
      updater: user
    )

    secondary_category = Category.create!(
      name: "Categoria Secundaria #{SecureRandom.hex(4)}",
      color: "#8899AA",
      creator: user,
      updater: user
    )

    Prompt.create!(
      title: "Prompt filtrado categoria",
      description: "Descricao primaria",
      content: "Conteudo primaria",
      category: primary_category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    Prompt.create!(
      title: "Prompt outra categoria",
      description: "Descricao secundaria",
      content: "Conteudo secundaria",
      category: secondary_category,
      visibility: "public",
      is_anonymous: false,
      creator: user,
      updater: user
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    get prompts_path, params: { category_id: primary_category.id, query: 'filtrado', search_in: 'title', order_by: 'recent' }

    assert_response :success
    assert_includes response.body, 'Prompt filtrado categoria'
    assert_not_includes response.body, 'Prompt outra categoria'
    assert_includes response.body, "value=\"#{primary_category.id}\""
  end

  test "create does not persist a favorite for the prompt owner" do
    user = User.create!(
      email: "prompt-create-user-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Create User",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Create #{SecureRandom.hex(4)}",
      color: "#113355",
      creator: user,
      updater: user
    )

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    assert_difference("Prompt.count", 1) do
      post prompts_path, params: {
        prompt: {
          title: "Prompt criado sem auto favorite",
          description: "Descricao sem auto favorite",
          content: "Conteudo sem auto favorite",
          category_id: category.id,
          is_anonymous: false,
          visibility: "public",
          tag_ids: [],
          team_ids: []
        }
      }
    end

    prompt = Prompt.order(:id).last

    assert_redirected_to prompt_path(prompt)
    assert_not Favorite.exists?(user: user, prompt: prompt)
  end

  test "show renders favorite toggle wiring for non-author viewers" do
    author = User.create!(
      email: "prompt-author-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Author",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    viewer = User.create!(
      email: "prompt-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Show #{SecureRandom.hex(4)}",
      color: "#224466",
      creator: author,
      updater: author
    )

    prompt = Prompt.create!(
      title: "Prompt show",
      description: "Descricao show",
      content: "Conteudo show",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: author,
      updater: author
    )

    post login_path, params: {
      session: {
        email: viewer.email,
        password: "123456"
      }
    }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, "data-favorite-path=\"#{prompt_favorite_path(prompt)}\""
    assert_includes response.body, "data-favorite-return-path=\"#{prompt_path(prompt)}\""
    assert_includes response.body, '@click="submitFavoriteToggle"'
    assert_not_includes response.body, I18n.t('prompts.editor.share')
    assert_includes response.body, I18n.t('prompts.vue.author_display.published_identified', author_name: '__AUTHOR_NAME__')
  end

  test "show renders comments section with vote controls" do
    author = User.create!(
      email: "prompt-comments-author-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Comments Author",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    commenter = User.create!(
      email: "prompt-comments-commenter-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Comments Commenter",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    viewer = User.create!(
      email: "prompt-comments-viewer-#{SecureRandom.hex(4)}@example.com",
      name: "Prompt Comments Viewer",
      role: "user",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Show Comments #{SecureRandom.hex(4)}",
      color: "#335577",
      creator: author,
      updater: author
    )

    prompt = Prompt.create!(
      title: "Prompt show comments",
      description: "Descricao show comments",
      content: "Conteudo show comments",
      category: category,
      visibility: "public",
      is_anonymous: false,
      creator: author,
      updater: author
    )

    comment = Comment.create!(
      prompt: prompt,
      creator: commenter,
      updater: commenter,
      content: "Comentario visivel no show"
    )

    post login_path, params: {
      session: {
        email: viewer.email,
        password: "123456"
      }
    }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, 'id="comments-section"'
    assert_includes response.body, comment.content
    assert_includes response.body, prompt_comment_vote_path(prompt, comment)
    assert_includes response.body, 'bi-caret-up-fill'
    assert_includes response.body, 'bi-caret-down-fill'
  end

  test "show renders formatted prompt content for viewers" do
    author = User.create!(email: "prompt-format-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Format Author", role: "user", password: "123456", password_confirmation: "123456")
    viewer = User.create!(email: "prompt-format-viewer-#{SecureRandom.hex(4)}@example.com", name: "Prompt Format Viewer", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Show Format #{SecureRandom.hex(4)}", color: "#335577", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt formatado", description: "Descricao", content: "<p><strong>Trecho importante</strong></p><ul><li>item um</li><li>item dois</li></ul>", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: viewer.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, '<strong>Trecho importante</strong>'
    assert_includes response.body, '<li>item um</li>'
    assert_includes response.body, 'prompt-rich-content'
  end

  test "show renders formatted comment highlights" do
    author = User.create!(email: "comment-format-author-#{SecureRandom.hex(4)}@example.com", name: "Comment Format Author", role: "user", password: "123456", password_confirmation: "123456")
    commenter = User.create!(email: "comment-format-user-#{SecureRandom.hex(4)}@example.com", name: "Comment Format User", role: "user", password: "123456", password_confirmation: "123456")
    viewer = User.create!(email: "comment-format-viewer-#{SecureRandom.hex(4)}@example.com", name: "Comment Format Viewer", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Comment Format #{SecureRandom.hex(4)}", color: "#668899", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt review", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)
    Comment.create!(prompt: prompt, creator: commenter, updater: commenter, content: "<p><mark class=\"comment-highlight comment-highlight--green\">novo trecho</mark></p><p><mark class=\"comment-highlight comment-highlight--yellow\">linha alterada</mark></p><p><mark class=\"comment-highlight comment-highlight--red\">linha removida</mark></p>")

    post login_path, params: { session: { email: viewer.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, 'comment-highlight--green'
    assert_includes response.body, 'comment-highlight--yellow'
    assert_includes response.body, 'comment-highlight--red'
  end

  test "show renders in-box minimal toolbar for editable prompt content" do
    author = User.create!(email: "prompt-editor-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Editor Author", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Show Editor #{SecureRandom.hex(4)}", color: "#557799", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt editavel", description: "Descricao", content: "<p>Conteudo base</p>", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: author.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, 'data-rich-editor-shell'
    assert_includes response.body, 'data-rich-editor-command="bold"'
    assert_includes response.body, 'data-rich-editor="true"'
  end

  test "show renders comment prompt button and comment editor for viewers without previous suggestion" do
    author = User.create!(email: "prompt-comment-button-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Comment Button Author", role: "user", password: "123456", password_confirmation: "123456")
    viewer = User.create!(email: "prompt-comment-button-viewer-#{SecureRandom.hex(4)}@example.com", name: "Prompt Comment Button Viewer", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Comment Button #{SecureRandom.hex(4)}", color: "#557799", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt com comentar", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: viewer.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, I18n.t('prompts.editor.comment_prompt')
    assert_includes response.body, 'data-prompt-comment-editor="true"'
  end

  test "show renders updated locked message when viewer already suggested improvement" do
    author = User.create!(email: "prompt-locked-message-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Locked Message Author", role: "user", password: "123456", password_confirmation: "123456")
    viewer = User.create!(email: "prompt-locked-message-viewer-#{SecureRandom.hex(4)}@example.com", name: "Prompt Locked Message Viewer", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Locked Message #{SecureRandom.hex(4)}", color: "#667788", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt bloqueado", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)
    Comment.create!(prompt: prompt, creator: viewer, updater: viewer, content: "Sugestao existente")

    post login_path, params: { session: { email: viewer.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, I18n.t('prompts.comments_section.single_comment_title')
    assert_includes response.body, I18n.t('prompts.comments_section.single_comment_body')
  end

  test "show renders delete prompt modal for users allowed to delete" do
    author = User.create!(email: "prompt-delete-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Delete Author", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Delete Prompt #{SecureRandom.hex(4)}", color: "#445566", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt removivel", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: author.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, I18n.t('prompts.actions.delete')
    assert_includes response.body, I18n.t('shared.delete_confirmation_modal.description', resource_name: I18n.t('prompts.resource_name_with_title', title: prompt.title))
  end

  test "show renders delete prompt modal for admin" do
    author = User.create!(email: "prompt-delete-admin-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Delete Admin Author", role: "user", password: "123456", password_confirmation: "123456")
    admin = User.create!(email: "prompt-delete-admin-#{SecureRandom.hex(4)}@example.com", name: "Prompt Delete Admin", role: "admin", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Delete Prompt Admin #{SecureRandom.hex(4)}", color: "#405060", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt removivel por admin", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: admin.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, I18n.t('prompts.actions.delete')
    assert_includes response.body, I18n.t('shared.delete_confirmation_modal.description', resource_name: I18n.t('prompts.resource_name_with_title', title: prompt.title))
  end

  test "show renders delete prompt modal for moderator" do
    author = User.create!(email: "prompt-delete-moderator-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Delete Moderator Author", role: "user", password: "123456", password_confirmation: "123456")
    moderator = User.create!(email: "prompt-delete-moderator-#{SecureRandom.hex(4)}@example.com", name: "Prompt Delete Moderator", role: "moderator", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Delete Prompt Moderator #{SecureRandom.hex(4)}", color: "#506070", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt removivel por moderator", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: moderator.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, I18n.t('prompts.actions.delete')
    assert_includes response.body, I18n.t('shared.delete_confirmation_modal.description', resource_name: I18n.t('prompts.resource_name_with_title', title: prompt.title))
  end

  test "show exposes copyable prompt content for read only view" do
    author = User.create!(email: "prompt-copy-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Copy Author", role: "user", password: "123456", password_confirmation: "123456")
    viewer = User.create!(email: "prompt-copy-viewer-#{SecureRandom.hex(4)}@example.com", name: "Prompt Copy Viewer", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Copy Prompt #{SecureRandom.hex(4)}", color: "#607080", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt copyable", description: "Descricao", content: "Crie um plano com etapas e riscos.", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: viewer.email, password: "123456" } }

    get prompt_path(prompt)

    assert_response :success
    assert_includes response.body, 'data-copy-content="Crie um plano com etapas e riscos."'
  end

  test "owner can destroy prompt" do
    author = User.create!(email: "prompt-destroy-owner-#{SecureRandom.hex(4)}@example.com", name: "Prompt Destroy Owner", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Destroy Owner #{SecureRandom.hex(4)}", color: "#112233", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt destroy owner", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: author.email, password: "123456" } }

    assert_difference("Prompt.count", -1) do
      delete prompt_path(prompt)
    end

    assert_redirected_to prompts_path
    assert_equal I18n.t('prompts.flashes.destroy.success'), flash[:success]
  end

  test "admin can destroy prompt from another user" do
    author = User.create!(email: "prompt-destroy-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Destroy Author", role: "user", password: "123456", password_confirmation: "123456")
    admin = User.create!(email: "prompt-destroy-admin-#{SecureRandom.hex(4)}@example.com", name: "Prompt Destroy Admin", role: "admin", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Destroy Admin #{SecureRandom.hex(4)}", color: "#223344", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt destroy admin", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: admin.email, password: "123456" } }

    assert_difference("Prompt.count", -1) do
      delete prompt_path(prompt)
    end

    assert_redirected_to prompts_path
    assert_equal I18n.t('prompts.flashes.destroy.success'), flash[:success]
  end

  test "moderator can destroy prompt from another user" do
    author = User.create!(email: "prompt-destroy-moderated-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Destroy Moderated Author", role: "user", password: "123456", password_confirmation: "123456")
    moderator = User.create!(email: "prompt-destroy-moderator-#{SecureRandom.hex(4)}@example.com", name: "Prompt Destroy Moderator", role: "moderator", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Destroy Moderator #{SecureRandom.hex(4)}", color: "#334455", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt destroy moderator", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: moderator.email, password: "123456" } }

    assert_difference("Prompt.count", -1) do
      delete prompt_path(prompt)
    end

    assert_redirected_to prompts_path
    assert_equal I18n.t('prompts.flashes.destroy.success'), flash[:success]
  end

  test "regular user cannot destroy another users prompt" do
    author = User.create!(email: "prompt-destroy-protected-author-#{SecureRandom.hex(4)}@example.com", name: "Prompt Protected Author", role: "user", password: "123456", password_confirmation: "123456")
    viewer = User.create!(email: "prompt-destroy-viewer-#{SecureRandom.hex(4)}@example.com", name: "Prompt Destroy Viewer", role: "user", password: "123456", password_confirmation: "123456")
    category = Category.create!(name: "Categoria Destroy Protected #{SecureRandom.hex(4)}", color: "#556677", creator: author, updater: author)
    prompt = Prompt.create!(title: "Prompt protegido", description: "Descricao", content: "Conteudo", category: category, visibility: "public", is_anonymous: false, creator: author, updater: author)

    post login_path, params: { session: { email: viewer.email, password: "123456" } }

    assert_no_difference("Prompt.count") do
      delete prompt_path(prompt)
    end

    assert_redirected_to prompt_path(prompt)
    assert_equal I18n.t('prompts.flashes.destroy.forbidden'), flash[:error]
  end

  test "update rejects team visibility without selected teams" do
    user = User.create!(
      email: "prompt-controller@example.com",
      name: "Prompt Controller",
      role: "admin",
      password: "123456",
      password_confirmation: "123456"
    )

    category = Category.create!(
      name: "Categoria Controller #{SecureRandom.hex(4)}",
      color: "#112233",
      creator: user,
      updater: user
    )

    team = Team.create!(
      name: "Equipe Controller #{SecureRandom.hex(4)}",
      creator: user,
      updater: user
    )
    TeamUser.create!(team: team, user: user, is_group_mod: true)

    prompt = Prompt.create!(
      title: "Prompt controller",
      description: "Descricao controller",
      content: "Conteudo controller",
      category: category,
      visibility: "team",
      is_anonymous: false,
      creator: user,
      updater: user,
      selected_team_ids_for_validation: [team.id]
    )
    prompt.prompt_teams.create!(team: team, creator: user)

    post login_path, params: {
      session: {
        email: user.email,
        password: "123456"
      }
    }

    patch prompt_path(prompt), params: {
      prompt: {
        title: prompt.title,
        description: prompt.description,
        content: prompt.content,
        category_id: category.id,
        is_anonymous: prompt.is_anonymous,
        visibility: "team",
        team_ids: []
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "devem incluir ao menos uma equipe quando a visibilidade for equipe"
    assert_equal [team.id], prompt.reload.team_ids
  end
end
