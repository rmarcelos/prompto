system_user = User.find_or_initialize_by(email: "system@app.local")
system_user.name = "System"
system_user.role = "admin"
system_user.password = "admin"
system_user.password_confirmation = "admin"
system_user.save!

admin = User.find_or_initialize_by(email: "admin@prompto.local")
admin.name = "Administrador"
admin.role = "admin"
admin.password = "123456"
admin.password_confirmation = "123456"
admin.save!

moderator = User.find_or_initialize_by(email: "moderator@prompto.local")
moderator.name = "Moderador"
moderator.role = "moderator"
moderator.password = "123456"
moderator.password_confirmation = "123456"
moderator.save!

member = User.find_or_initialize_by(email: "user@prompto.local")
member.name = "Usuário Base"
member.role = "user"
member.password = "123456"
member.password_confirmation = "123456"
member.save!

ranking_users = [
	{ email: "ana@prompto.local", name: "Ana Insights", role: "user" },
	{ email: "bruno@prompto.local", name: "Bruno Builder", role: "user" },
	{ email: "carla@prompto.local", name: "Carla Copy", role: "user" },
	{ email: "diego@prompto.local", name: "Diego Dados", role: "user" },
	{ email: "elisa@prompto.local", name: "Elisa Engenho", role: "user" },
	{ email: "fabio@prompto.local", name: "Fabio Fluxo", role: "user" }
].to_h do |attributes|
	user = User.find_or_initialize_by(email: attributes[:email])
	user.name = attributes[:name]
	user.role = attributes[:role]
	user.password = "123456"
	user.password_confirmation = "123456"
	user.save!

	[attributes[:email], user]
end

categories = [
	{ name: "Produtividade", color: "#2563eb" },
	{ name: "Marketing", color: "#dc2626" },
	{ name: "Desenvolvimento", color: "#059669" }
].map do |attributes|
	category = Category.find_or_initialize_by(name: attributes[:name])
	category.assign_attributes(attributes.merge(creator: admin, updater: admin))
	category.save!
	category
end

tags = [
	{ name: "gpt", color: "#7c3aed" },
	{ name: "copywriting", color: "#ea580c" },
	{ name: "rails", color: "#be123c" }
].map do |attributes|
	tag = Tag.find_or_initialize_by(name: attributes[:name])
	tag.assign_attributes(attributes.merge(creator: admin, updater: admin))
	tag.save!
	tag
end


# Equipes de exemplo vinculadas ao usuário systema
systema = User.find_by(email: "system@app.local")
raise "Usuário systema não encontrado" unless systema

team_names = [
	"Equipe Alpha",
	"Equipe Beta",
	"Equipe Gamma",
	"Equipe Teste",
	"Equipe Demo"
]

team_names.each do |name|
	team = Team.find_or_create_by!(name: name) do |new_team|
		new_team.creator = systema
		new_team.updater = systema
		new_team.created_at = Time.current
		new_team.updated_at = Time.current
	end

	team.update!(creator: systema, updater: systema) if team.creator != systema || team.updater != systema

	team_user = TeamUser.find_or_initialize_by(team: team, user: systema)
	team_user.is_group_mod = true
	team_user.created_at ||= Time.current
	team_user.save!
end

team = Team.find_or_initialize_by(name: "Equipe Produto")
team.creator = admin
team.updater = admin
team.save!

[
	{ user: admin, is_group_mod: true },
	{ user: moderator, is_group_mod: true },
	{ user: member, is_group_mod: false }
].each do |attributes|
	team_user = TeamUser.find_or_initialize_by(team: team, user: attributes[:user])
	team_user.is_group_mod = attributes[:is_group_mod]
	team_user.created_at ||= Time.current
	team_user.save!
end

public_prompt = Prompt.find_or_initialize_by(title: "Checklist para refinar um prompt")
public_prompt.assign_attributes(
	description: "Estrutura base para revisar clareza, contexto e formato de resposta.",
	content: "Analise este prompt, identifique ambiguidades e reescreva em formato objetivo.",
	category: categories.find { |category| category.name == "Produtividade" },
	visibility: "public",
	is_anonymous: false,
	creator: admin,
	updater: admin
)
public_prompt.save!

team_prompt = Prompt.find_or_initialize_by(title: "Plano de rollout interno")
team_prompt.assign_attributes(
	description: "Prompt privado para documentar um rollout entre membros do time.",
	content: "Crie um plano de rollout com riscos, dependências, checklist e responsáveis.",
	category: categories.find { |category| category.name == "Desenvolvimento" },
	visibility: "team",
	is_anonymous: false,
	creator: moderator,
	updater: moderator
)
team_prompt.selected_team_ids_for_validation = [team.id]
team_prompt.save!

PromptTeam.find_or_create_by!(prompt: team_prompt, team: team) do |prompt_team|
	prompt_team.creator = moderator
	prompt_team.created_at = Time.current
	prompt_team.updated_at = Time.current
end

{
	public_prompt => %w[gpt copywriting],
	team_prompt => %w[gpt rails]
}.each do |prompt, tag_names|
	tag_names.each do |tag_name|
		tag = tags.find { |item| item.name == tag_name }
		PromptTag.find_or_create_by!(prompt: prompt, tag: tag)
	end
end

comment = Comment.find_or_initialize_by(prompt: public_prompt, creator: member, content: "Esse prompt funciona melhor quando o contexto do público-alvo é incluído.")
comment.updater = member
comment.save!

reply = Comment.find_or_initialize_by(prompt: public_prompt, creator: admin, content: "Boa observação. Também vale pedir formato de saída logo no início.")
reply.updater = admin
reply.save!

Favorite.find_or_create_by!(prompt: public_prompt, user: member) do |favorite|
	favorite.created_at = Time.current
end

PromptUsage.find_or_create_by!(prompt: public_prompt, user: member, created_at: Time.current.beginning_of_day)

public_prompt.update_columns(
	favorites_count: public_prompt.favorites.count,
	uses_count: public_prompt.prompt_usages.count,
	pinned_comment_id: comment.id
)

ranking_category = categories.find { |category| category.name == "Marketing" }

ranking_prompts = {
	"ana@prompto.local" => {
		title: "Framework de campanha omnichannel",
		description: "Prompt para estruturar campanhas com foco em canais, metas e experimentos.",
		content: "Monte um plano de campanha omnichannel com objetivos, canais, copies-base e indicadores.",
		favorite_emails: ["bruno@prompto.local", "carla@prompto.local", "diego@prompto.local", "elisa@prompto.local", "fabio@prompto.local"]
	},
	"bruno@prompto.local" => {
		title: "Checklist de refatoração Rails",
		description: "Prompt para revisar acoplamento, queries e responsabilidades de serviços.",
		content: "Analise este trecho Rails e proponha um plano de refatoração com foco em consultas, responsabilidades e testes.",
		favorite_emails: ["ana@prompto.local", "carla@prompto.local", "diego@prompto.local", "elisa@prompto.local"]
	},
	"carla@prompto.local" => {
		title: "Sequência de email para ativação",
		description: "Prompt para criar uma cadência de ativação com gatilhos e CTAs.",
		content: "Crie uma sequência de emails de ativação com assunto, corpo e CTA para três segmentos.",
		favorite_emails: ["ana@prompto.local", "bruno@prompto.local", "diego@prompto.local"]
	},
	"diego@prompto.local" => {
		title: "Resumo executivo de indicadores",
		description: "Prompt para transformar métricas em um resumo objetivo para liderança.",
		content: "Transforme estes indicadores em um resumo executivo com tendências, alertas e próximos passos.",
		favorite_emails: ["ana@prompto.local", "bruno@prompto.local"]
	}
}

ranking_prompts.each do |creator_email, attributes|
	creator = ranking_users.fetch(creator_email)
	prompt = Prompt.find_or_initialize_by(title: attributes[:title])
	prompt.assign_attributes(
		description: attributes[:description],
		content: attributes[:content],
		category: ranking_category,
		visibility: "public",
		is_anonymous: false,
		creator: creator,
		updater: creator
	)
	prompt.save!

	attributes[:favorite_emails].each do |favorite_email|
		Favorite.find_or_create_by!(prompt: prompt, user: ranking_users.fetch(favorite_email)) do |favorite|
			favorite.created_at = Time.current
		end
	end

	prompt.update_columns(
		favorites_count: prompt.favorites.count,
		uses_count: prompt.prompt_usages.count
	)
end
