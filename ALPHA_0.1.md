# Pintacred Alpha 0.1

Marco: primeira versão preparada para build Android de demonstração.

## Incluído
- cadastro e login demo;
- autenticação por token;
- home;
- simulador de R$ 100 a R$ 500;
- solicitação e motor de regras fictício;
- proposta demo;
- aceite e contrato demo;
- cronograma de parcelas;
- lista de empréstimos demo;
- banner persistente para não usar dados reais.

## Importante sobre o APK
O código está preparado para compilação, mas este pacote NÃO contém APK pré-compilado. O ambiente que gerou o pacote não possui Flutter/Android SDK. Há duas formas reproduzíveis de gerar o APK:

1. GitHub Actions: publicar este repositório no GitHub e executar o workflow `Android Debug APK`.
2. Computador com Flutter: executar `API_BASE=http://SEU_BACKEND:8000 ./scripts/build_android.sh`.

## Limitação de rede
`10.0.2.2` funciona para um emulador Android acessando o backend no mesmo computador. Em um celular físico, o backend precisa estar acessível por uma URL HTTPS ou pelo IP local do computador durante testes na mesma rede.

## Antes de qualquer piloto real
Não usar dados pessoais reais, não movimentar dinheiro e não interpretar as regras demo como política de crédito. Produção exigirá infraestrutura, segurança, compliance e integração regulada próprias.
