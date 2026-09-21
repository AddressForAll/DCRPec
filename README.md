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
C3 | LOCALIDADE | ~0,6%
C2 | LOGRADOURO | ~97,1%
C1 | GRANDE_USUARIO | ~1,4%
C1 | UNIDADE_OPERACIONAL | ~0,8%
C1 | CPC - Caixa Postal do Correio | 0,13%

<img width="1287" height="750" alt="Captura de tela de 2026-09-21 09-28-01" src="https://github.com/user-attachments/assets/37302cc4-f498-4e58-b792-6a7ad86febd2" />

Resumindo o que seria o processo de compactação, dos dois lados, DNE e endereço postal original:
* *"Rua Planalto 4, 15 • Alto da Lagonhinha, Capistrano - CE"* **=** "`BR-CE-Capistrano`, `AltoLagonhinha`, `R_Planalto4`, `15`" <br/>"CEP 62748-000"  **=** `BR-CE-Capistrano`<br/> Portanto o CEP substituí `BR-CE-Capistrano` e fica `AltoLagonhinha-R_Planalto4~15`.
* *"Avenida Braz Leme, 2000 • Santana, São Paulo - SP"* **=** `BR-SP-SaoPaulo`, `Santana`, `Av_BrazLeme`, `2000`<br/>"CEP 62748-000" **=** "`BR-SP-SaoPaulo`, `Santana`, `Av_BrazLeme`"<br/> Portanto o CEP substituí `BR-SP-SaoPaulo-Santana-Av_BrazLeme` e fica a numeração predial como `~2000`.

As funções de compactação, na pasta [`/src`](./src), garantem strings DNE padronizadas, mas as diferentes fontes de endereços, tais como OpenStreetMap, CNEFE e Prefeituras, nem sempre seguem o mesmo padrão, de modo que a canonização exige um recurso a mais que é a tabela de sinônimos. Exemplos termos sinônimos canizados, *sinônimo*→*canônico*:

* *"Rua planalto Quatro"* **→** *"Rua Planalto 4"*
* ...
