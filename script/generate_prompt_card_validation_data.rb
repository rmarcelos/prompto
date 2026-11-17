owner = User.first or abort("no user")

category = Category.first || Category.create!(
  name: "validacao",
  creator: owner,
  updater: owner
)

[
  ["Validacao Likes 7", 7],
  ["Validacao Likes 42", 42],
  ["Validacao Likes 123", 123]
].each do |title, count|
  prompt = Prompt.find_or_initialize_by(title: title, creator: owner)
  prompt.description = "Prompt gerado automaticamente para validar a escala visual do contador de likes."
  prompt.content = "Conteudo de teste para #{title}."
  prompt.category = category
  prompt.updater = owner
  prompt.visibility = "public"
  prompt.save!
  prompt.update_columns(favorites_count: count)

  puts "#{prompt.title}: #{prompt.reload.favorites_count} likes"
end