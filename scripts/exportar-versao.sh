#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Funções auxiliares
# ============================================================

encerrar_com_erro() {
    printf '\n%s\n\n' "$1"
    exit 1
}

resposta_negativa() {
    [[ "$1" =~ ^[nN]$ ]]
}

# ============================================================
# Verificações iniciais
# ============================================================

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    encerrar_com_erro \
        'Este comando deve ser executado dentro de um repositório Git.'
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    encerrar_com_erro \
        'O repositório não possui um remoto chamado origin configurado.'
fi

if [[ -n "$(git status --porcelain)" ]]; then
    printf '\n'
    printf 'Existem alterações locais não commitadas.\n'
    printf '\n'
    git status --short
    printf '\n'
    printf 'Conclua ou descarte essas alterações antes de exportar uma versão oficial.\n'
    printf '\n'
    exit 1
fi

# ============================================================
# Atualização das tags
# ============================================================

printf '\n'
printf 'Atualizando as tags do repositório remoto...\n'
printf '\n'

git fetch origin --prune --tags

# ============================================================
# Listagem das tags oficiais
# ============================================================

declare -a tags_disponiveis=()

while IFS= read -r tag; do
    if [[ -n "$tag" ]]; then
        tags_disponiveis+=("$tag")
    fi
done < <(
    git tag \
        --list 'PCB-Rev-*_SW-v*' \
        --sort=-version:refname
)

if [[ "${#tags_disponiveis[@]}" -eq 0 ]]; then
    printf '\n'
    printf 'Nenhuma tag oficial foi encontrada.\n'
    printf '\n'
    printf 'Padrão esperado:\n'
    printf '  PCB-Rev-X.Y_SW-vX.Y.Z\n'
    printf '\n'
    exit 1
fi

printf '\n'
printf 'Tags oficiais disponíveis:\n'
printf '\n'

for indice in "${!tags_disponiveis[@]}"; do
    printf '%d) %s\n' \
        "$((indice + 1))" \
        "${tags_disponiveis[$indice]}"
done

printf '\n'

# ============================================================
# Seleção da tag
# ============================================================

while true; do
    read -r -p 'Escolha a tag que deseja exportar: ' opcao_tag

    if [[ ! "$opcao_tag" =~ ^[0-9]+$ ]]; then
        printf 'Opção inválida. Digite apenas um número.\n'
        continue
    fi

    if (( opcao_tag < 1 || opcao_tag > ${#tags_disponiveis[@]} )); then
        printf 'Opção inválida. Escolha um número entre 1 e %d.\n' \
            "${#tags_disponiveis[@]}"
        continue
    fi

    break
done

nome_tag="${tags_disponiveis[$((opcao_tag - 1))]}"

# ============================================================
# Validação da tag
# ============================================================

padrao_tag='^PCB-Rev-([0-9]+\.[0-9]+)_SW-v([0-9]+\.[0-9]+\.[0-9]+)$'

if [[ ! "$nome_tag" =~ $padrao_tag ]]; then
    encerrar_com_erro \
        'A tag selecionada não segue o padrão oficial esperado.'
fi

revisao_pcb="${BASH_REMATCH[1]}"
versao_sw="${BASH_REMATCH[2]}"

# ============================================================
# Identificação do repositório
# ============================================================

url_origin="$(git remote get-url origin)"

nome_repositorio="$(basename "$url_origin")"
nome_repositorio="${nome_repositorio%.git}"

if [[ -z "$nome_repositorio" ]]; then
    encerrar_com_erro \
        'Não foi possível identificar o nome do repositório.'
fi

# ============================================================
# Identificação do commit associado à tag
# ============================================================

commit_tag="$(git rev-list -n 1 "$nome_tag")"

data_commit="$(
    git show \
        -s \
        --format='%ad' \
        --date=format:'%Y%m%d' \
        "$commit_tag"
)"

if [[ -z "$data_commit" ]]; then
    encerrar_com_erro \
        'Não foi possível identificar a data do commit associado à tag.'
fi

# ============================================================
# Definição do nome do arquivo exportado
# ============================================================

nome_exportacao="${nome_repositorio}_PCB-Rev-${revisao_pcb}_SW-v${versao_sw}_${data_commit}"

diretorio_exportacao='exports'

arquivo_zip="${diretorio_exportacao}/${nome_exportacao}.zip"

# ============================================================
# Resumo
# ============================================================

printf '\n'
printf 'Versão selecionada:\n'
printf '  Tag:            %s\n' "$nome_tag"
printf '  Revisão PCB:    %s\n' "$revisao_pcb"
printf '  Versão SW:      %s\n' "$versao_sw"
printf '\n'

printf 'Commit associado:\n'
printf '  Hash:           %s\n' "$commit_curto"
printf '  Data:           %s\n' "$commit_data"
printf '  Autor:          %s\n' "$commit_autor"
printf '  Mensagem:       %s\n' "$commit_mensagem"
printf '\n'

printf 'Arquivo que será gerado:\n'
printf '  %s\n' "$arquivo_zip"
printf '\n'

# ============================================================
# Verificação de arquivo existente
# ============================================================

if [[ -e "$arquivo_zip" ]]; then
    printf 'Já existe um arquivo com este nome.\n'
    printf '\n'

    read -r -p 'Deseja substituí-lo? [s/N]: ' resposta_substituir
    resposta_substituir="${resposta_substituir:-N}"

    if [[ ! "$resposta_substituir" =~ ^[sS]$ ]]; then
        printf '\n'
        printf 'Operação cancelada.\n'
        printf '\n'
        exit 0
    fi
fi

# ============================================================
# Confirmação
# ============================================================

read -r -p 'Confirma a geração do arquivo exportado? [S/n]: ' resposta_confirmacao
resposta_confirmacao="${resposta_confirmacao:-S}"

if resposta_negativa "$resposta_confirmacao"; then
    printf '\n'
    printf 'Operação cancelada.\n'
    printf '\n'
    exit 0
fi

# ============================================================
# Geração do arquivo ZIP
# ============================================================

mkdir -p "$diretorio_exportacao"

arquivo_temporario="${arquivo_zip}.tmp"

rm -f "$arquivo_temporario"

printf '\n'
printf 'Gerando o arquivo exportado...\n'
printf '\n'

git archive \
    --format=zip \
    --prefix="${nome_exportacao}/" \
    --output="$arquivo_temporario" \
    "$nome_tag"

mv -f "$arquivo_temporario" "$arquivo_zip"

# ============================================================
# Geração do SHA-256
# ============================================================

if command -v sha256sum >/dev/null 2>&1; then

    hash_sha256="$(
        sha256sum "$arquivo_zip" |
            awk '{print $1}'
    )"

elif command -v certutil.exe >/dev/null 2>&1; then

    hash_sha256="$(
        certutil.exe \
            -hashfile \
            "$(cygpath -w "$arquivo_zip")" \
            SHA256 2>/dev/null |
            tr -d '\r' |
            awk 'NR == 2 {
                gsub(/[[:space:]]/, "")
                print
            }'
    )"

else
    hash_sha256='Não disponível'
fi

tamanho_bytes="$(
    wc -c <"$arquivo_zip" |
        tr -d '[:space:]'
)"

# ============================================================
# Resultado
# ============================================================

printf '\n'
printf 'Arquivo exportado com sucesso.\n'
printf '\n'

printf 'Arquivo:\n'
printf '  %s\n' "$arquivo_zip"
printf '\n'

printf 'Origem:\n'
printf '  %s\n' "$nome_tag"
printf '\n'

printf 'Commit:\n'
printf '  %s\n' "$commit_curto"
printf '\n'

printf 'Tamanho:\n'
printf '  %s bytes\n' "$tamanho_bytes"
printf '\n'

printf 'SHA-256:\n'
printf '  %s\n' "$hash_sha256"
printf '\n'