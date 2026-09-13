# Cifra Band 1.5.6+24

Atualizacao obrigatoria de seguranca e confiabilidade para o beta.

- Busca identifica artistas separadamente de musicas, tolera erros em nomes e usa dados de catalogo para desempatar homonimos. Testados Jorge & Mateus, "jorgeve mayheus", "Jorge e Matheus", Fernandinho e Gabriela Rocha.
- Corrigida a descoberta de URLs de duplas, incluindo Sol Nos Olhos de Jorge & Mateus no Cifra Club. A pagina consultada informa tom E.
- Popup central ao abrir uma cifra, com cancelar, tentar novamente e reportar problema.
- Diagramas conferem as notas da forma antes de exibir. Correcoes em D7/F#, Cdim7, Am7M e nonas alteradas. Sem forma exata, o app nao troca silenciosamente o acorde.
- Dono global identificado pelo UID confirmado no Firebase Auth, nunca pelo e-mail editavel de um perfil.
- Entrada na equipe valida convite no servidor. Presenca e votos alteram apenas os dados de quem enviou a solicitacao.
- Contatos adicionam somente a propria lista; nao sobrescrevem a lista de outra pessoa. Perfis publicos minimos separados de tokens e dados privados.
- Cifras particulares ficam dentro da setlist, herdando seu acesso. Migracao aditiva preserva os documentos antigos.
- Downloads offline separados por conta, verificacao do selo de salvo e limpeza dos arquivos excedentes. Downloads antigos so sao recuperados depois da verificacao de acesso no servidor.
- Biblioteca oficial salva cifra e historico na mesma transacao e detecta edicoes concorrentes no editor.
- Importacao preserva as linhas da letra e nao usa o primeiro acorde como certeza do tom.
- Toques nas notificacoes abrem suporte ou escala com verificacao de permissao. Logout desvincula o dispositivo e invalida o token quando a rede permite.
- Atualizador verifica tamanho e SHA-256 quando informado, interrompe download travado e remove arquivo parcial. Atualizacao obrigatoria conhecida persiste entre aberturas; instalador pode ser reaberto sem baixar novamente.
- Busca automatica de YouTube desativada por padrao no backend enquanto o recurso permanece adiado para 2.0.

Limites: notificacao push depende da permissao e do sistema operacional; Render Free ainda pode adormecer. A busca usa evidencias e nao garante 99% em todo o catalogo. Recursos de YouTube sincronizado, deteccao de tom por audio e uma migracao de infraestrutura paga nao fazem parte desta correcao.
