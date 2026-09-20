# DCRPec
O *Diretório CRP de Endereços Canônicos* (**DCRPec**) foi inspirado no [banco de dados holandês de endereços oficiais](https://www.kadaster.nl/-/gratis-download-bag-extract), conhecido como BAG, onde cada endereço é expresso como string curta, iniciada pelo código postal e sem redundância de informação (conhecido como "Nummeraanduiding").

Os CRPs foram definidos em [`git.AddressForAll.org/CRP`](https://git.AddressForAll.org/CRP), contornando a [insegurança jurídica criada pelos Correios](https://pt.stackoverflow.com/questions/54539/cep-da-minha-cidade-onde-posso-encontrar-fonte-aberta-atualizada-e-confi%c3%a1vel/56664#56664) para a publicação direta dos CEP.

## Conteúdo deste repositório
A verão [`git`](https://en.wikipedia.org/wiki/Git) do DCRPec é um repositório de [arquivos CSV](https://en.wikipedia.org/wiki/Comma-separated_values), com no máximo 1 milhão de linhas por arquivo, garantindo a visualização *online*, as restrições de tamanho de arquivo nos git's públicos gratuitos, e que operações `git diff` possam ser realizadas a cada atualização.

Os CSVs são distribuídos em pastas, por município, e os arquivos nomeados por início de faixa de CEP (ou iniciais de nome de bairro ou iniciais de nome de rua). 

### Endereço canônico compacto
Seguindo a boa prática de se tratar apenas endereços minimamente padronizados, e de se expressar esses endereços através strings únicas, compactas e canônicas, utilizáveis em URNs, URLs e APIs em geral.  Aqui o termo *endereço* refere-se ao "endereço de taxi", que deixa em via pública o seu passageiro, próximo da entrada principal do lote.  Não são  tratados endereços domiciliares, ou seja, **não incluí o *complemento do endereço***, que leva até o domicílio (edifícios, partes, apartamentos ou lotes interiores a condomínios horizontais).

A compactação tem como ponto de partida o CEP (neste git convertido para **CRP**), que segue a seguinte estatística e a lógica dos exemplos apresentados abaixo.

Caso | tipo | percentual
-----|------|--------
C3 | LOGRADOURO | ~97,1%
C2 | LOCALIDADE | ~0,6%
C1 | GRANDE_USUARIO | ~1,4%
C1 | UNIDADE_OPERACIONAL | ~0,8%
C1 | CPC - Caixa Postal do Correio | 0,13%

<img width="1288" height="786" alt="Captura de tela de 2026-09-20 11-50-04" src="https://github.com/user-attachments/assets/c344f79b-036a-4c4b-bea1-90775ddd4015" />
