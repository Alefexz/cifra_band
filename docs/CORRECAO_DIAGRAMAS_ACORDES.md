# Diagramas de acordes

## Diagnostico

O anexo recebido foi apenas pasted-text.txt. Os cinco arquivos de substituicao citados nele nao estavam anexados. A correcao foi feita sobre o codigo existente, preservando as funcionalidades da tela.

- Violao: o painter antigo ja desenhava linhas ortogonais, nao perspectiva. Entretanto, distribuia a largura por quase todo o card, com apenas 92/132 pixels de altura, achatando o desenho. Pontos, trastes e legendas tinham escalas diferentes; nao havia dados nem desenho de pestana.
- Teclado: os marcadores das teclas brancas eram desenhados em 72% da altura, mas seus textos em 90%; as teclas pretas tambem usavam centros diferentes para texto e circulo. Alem disso, o Paint das bordas estava em modo fill, sobrepondo o preenchimento branco.
- Modal: a coluna nao tinha rolagem nem altura maxima, insuficiente para acomodar diagramas legiveis com texto ampliado.

## Arquivos e ligacoes

- lib/core/music/chord_shape_catalog.dart: catalogo separado e modelos GuitarChordShape/GuitarBarre. Pestanas explicitas; dedos opcionais. O F tem digitacao 1-3-4-2-1-1 e pestana da primeira a sexta corda. Nao sao inferidas pestanas so porque ha notas na mesma casa.
- lib/core/services/chord_study_service.dart: consulta o catalogo e mantem a validacao de notas e baixo. insightFor, guitarShapeFor e keyboardNotes conservaram suas assinaturas. Reexporta os modelos para compatibilidade.
- lib/features/songs/presentation/widgets/chord_diagrams/guitar_chord_diagram.dart: grid proporcional, coordenadas compartilhadas para cordas e pontos, o/x alinhados, nomes das cordas e margem para a casa inicial. Sem shape, somente texto; sem fingers, pontos sem numeracao.
- lib/features/songs/presentation/widgets/chord_diagrams/keyboard_chord_diagram.dart: contornos em stroke, nome centralizado no mesmo ponto do marcador, teclas brancas/pretas corretas e fallback sem teclado para lista vazia.
- lib/features/songs/presentation/screens/cifra_screen.dart: usa os novos componentes na lista e no modal. Os painters privados antigos foram removidos. O modal ganhou limite de altura e rolagem, sem trocar a paleta nem o formato dos cards.
- test/chord_diagrams_test.dart: oito testes novos para regressao e capturas opcionais com CHORD_PREVIEW=1.

## Validacao e limites

- 80 testes Flutter passaram.
- flutter analyze nos cinco arquivos alterados e no teste: No issues found.
- Capturas claras/escuras: build/chord-previews. Conferidos G, F, D/F#, C#7 sem shape e G# na quarta casa; teclado com G-B-D e F#-D-A.
- Teste do modal na propria CifraScreen, em 320x640 e escala de texto 1.3, usando cifra local de teste, abertura ao tocar no F e troca de instrumento.
- O teclado mostra classes de notas em uma oitava; nao promete uma disposicao especifica de vozes ou baixo para a mao esquerda. O baixo continua informado pelo acorde e pelo servico musical.
- Nao houve teste em telefone fisico nem abertura de uma cifra baixada ao vivo: adb nao mostrou dispositivo disponivel, somente um emulador offline.
- APK debug gerado localmente na etapa de correcao. A publicacao posterior, autorizada pelo usuario, esta registrada em DEPLOY_1_5_7.md.
