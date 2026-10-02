# Documentação do Carregador de Dados eDNE dos Correios

## Visão Geral

Este documento descreve como criar um banco de dados PostgreSQL e carregar os dados do eDNE dos Correios do Brasil utilizando a ferramenta `edne-correios-loader`.

## Fonte de Dados

Origem do download:

```bash
wget -c https://www2.correios.com.br/sistemas/edne/download/eDNE_Basico.zip
```

**Nota:** Não é necessário baixar o arquivo ZIP manualmente ao utilizar o `edne-correios-loader`, pois a ferramenta pode obter os dados automaticamente.

## Biblioteca do Carregador

Biblioteca:

- `edne-correios-loader`
- Página do projeto: https://libraries.io/pypi/edne-correios-loader
- Licença: MIT
- Identificador SPDX: https://spdx.org/licenses/MIT.html

## Criar Banco de Dados PostgreSQL

Conecte-se ao PostgreSQL:

```bash
psql -U postgres
```

Crie o banco de dados:

```sql
CREATE DATABASE correios;
```

Saia do PostgreSQL:

```sql
\q
```

## Instalar o uv

Instale o `uv`:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Ative o `uv` no terminal atual:

```bash
source $HOME/.local/bin/env
```

## Carregar Apenas a Tabela Principal

Utilize o comando a seguir para carregar apenas a tabela principal:

```bash
uvx --from 'edne-correios-loader[postgresql]' edne-correios-loader load --database-url postgresql://postgres:postgres@localhost:5432/correios
```

## Carregar Todas as Tabelas - Utilizamos esta

Utilize o comando a seguir para preservar a estrutura completa de tabelas fornecida pelo carregador:

```bash
uvx --from 'edne-correios-loader[postgresql]' edne-correios-loader load --database-url postgresql://postgres:postgres@localhost:5432/correios --tables all
```

