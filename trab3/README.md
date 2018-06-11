# Roteamento com árvore geradora em Terra

O codigo foi otimizado para redes com numero de linhas e colunas prédefinidas no codigo, alem de ter que colocar o resultado do produto desses dois na declaração da tabela de roteamento, não funcionando caso as mesmas não correspondam ao numero de linhas/colunas especificados na criação da simulação. A otimização consiste na utilização de uma tabela de roteamento de tamanho N_LINHAS * N_COLUNAS, para evitar desperdidio de memoria. Pelos meus testes, até 20 (4x5) nós funciona normal. Acima dos 20 nós, alguns nós chegam ao limite de memoria e varias mensagens são perdidas, interferindo nos pedidos de temperaturas mais distantes do nó raiz.