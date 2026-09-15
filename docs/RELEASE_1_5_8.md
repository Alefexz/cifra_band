# Cifra Band 1.5.8+26

- Botao + na cifra para adicionar a uma setlist propria ou compartilhada. Tambem permite criar uma nova setlist.
- Preserva tom, forma, capo e conteudo exibidos; repeticao da mesma versao nao cria outra copia pelo novo seletor.
- Topo da cifra mais enxuto. Tom permanece na barra; simplificacao, modo de leitura, anotacoes e biblioteca oficial permanecem nas configuracoes.
- Menu da setlist oferece baixar/atualizar a copia offline e abrir o download. Disponivel para dono e colaboradores, sem liberar edicao administrativa.
- Download verifica acesso e a lista atual no Firestore, reaproveita copias locais completas pelo ID imutavel da cifra e busca no banco os itens faltantes. Se o documento nao tiver conteudo, consulta o cache global e depois o backend. Cifras salvas completas nao sao substituidas por outra versao.
- Ordem, tom, capo e observacoes preservados. Se faltar uma cifra ou houver falha, nao anuncia download completo nem substitui o download anterior por uma lista parcial.
- Downloads separados por conta, disponiveis tambem em Setlists > Setlists Offline. Atualizar o download requer internet; reproduzir a copia baixada nao.

Limites: ausencia de documento sem metadados gera erro explicito, nao uma cifra inventada. A copia offline e uma fotografia da setlist; apos modifica-la, use atualizar download. Nenhuma mudanca em regras ou migracao de dados foi necessaria.

Validacao: testes Flutter, regras no emulador e capturas da tela de cifra pequena. Nao houve teste em telefone fisico. Atualizacao opcional para builds 25 ou superiores; mantida a exigencia de atualizar builds antigos com correcoes anteriores.
