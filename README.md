# Prompto

Aplicação Rails 8 com Propshaft, Turbo, Stimulus, Vue 3 via CDN, PostgreSQL e ActiveStorage.

## Requisitos

- Ruby conforme [.ruby-version](.ruby-version)
- PostgreSQL 17+
- libvips
- Docker e docker-compose para execução containerizada

## Ambiente local sem Docker

Configure as variáveis de banco conforme necessário:

```sh
export POSTGRES_HOST=localhost
export POSTGRES_DB=prompto_development
export POSTGRES_TEST_DB=prompto_test
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
```

Depois rode:

```sh
bundle install
bin/rails db:prepare
bin/dev
```

## Docker

O ambiente de desenvolvimento sobe web e PostgreSQL:

```sh
docker-compose up --build
```

O serviço web executa `bin/rails db:prepare` antes de iniciar o servidor em `http://localhost:3000`.

## ActiveStorage e S3

Desenvolvimento e testes usam storage local. Produção usa S3 por padrão com:

```sh
export ACTIVE_STORAGE_SERVICE=amazon
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
export AWS_S3_BUCKET=prompto-production
```

As imagens de perfil são armazenadas via ActiveStorage e renderizadas por URLs assinadas do Rails.

## Qualidade

```sh
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
```
