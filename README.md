# Pintacred — Alpha 0.1

Primeiro pacote preparado para build Android do MVP demonstrativo.

## Estrutura
- `mobile/`: aplicativo Flutter.
- `backend/`: API FastAPI e banco de desenvolvimento.
- `scripts/run_backend.sh`: sobe o backend local.
- `scripts/build_android.sh`: gera o APK debug quando Flutter estiver instalado.
- `.github/workflows/android-debug.yml`: build reproduzível na nuvem via GitHub Actions.
- `ALPHA_0.1.md`: estado do produto e instruções.

## Teste local do backend
Requer Python 3.11+.

```bash
./scripts/run_backend.sh
```

Documentação da API: `http://localhost:8000/docs`.

## Build Android
Veja `ALPHA_0.1.md`. O APK de debug é somente para teste interno.
