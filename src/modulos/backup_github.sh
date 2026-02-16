#!/usr/bin/env bash
# ============================================================
# backup_github.sh — Módulo de backup de repositorios GitHub
# Clona mirrors completos y los actualiza incrementalmente
# ============================================================

backup_github() {
    local log="${BACKUP_LOG_DIR}/github.log"
    local errores=0

    mkdir -p "$BACKUP_GITHUB_DIR"

    # Obtener lista de repos propios
    local repos
    repos=$(gh repo list --limit 200 --json nameWithOwner --jq '.[].nameWithOwner' 2>&1)

    if [[ $? -ne 0 ]]; then
        logger_escribir "$log" "ERROR" "No se pudo obtener lista de repos: ${repos}"
        return 1
    fi

    if [[ -z "$repos" ]]; then
        logger_escribir "$log" "ERROR" "La lista de repos está vacía"
        return 1
    fi

    while IFS= read -r repo_full; do
        # repo_full es "owner/repo_name", extraer solo el nombre
        local repo_name="${repo_full##*/}"
        local repo_dir="${BACKUP_GITHUB_DIR}/${repo_name}.git"

        if [[ -d "$repo_dir" ]]; then
            # Ya existe: actualizar incrementalmente
            logger_escribir "$log" "INFO" "${repo_name}: actualizando mirror"
            local salida
            salida=$(git -C "$repo_dir" remote update --prune 2>&1)

            if [[ $? -eq 0 ]]; then
                logger_escribir "$log" "OK" "${repo_name}: actualizado"
            else
                logger_escribir "$log" "ERROR" "${repo_name}: fallo al actualizar - ${salida}"
                errores=$((errores + 1))
            fi
        else
            # No existe: clonar mirror por primera vez
            # Intentar SSH primero, si falla intentar HTTPS
            logger_escribir "$log" "INFO" "${repo_name}: clonando mirror (SSH)"
            local salida
            salida=$(git clone --mirror "git@github.com:${repo_full}.git" "$repo_dir" 2>&1)

            if [[ $? -eq 0 ]]; then
                logger_escribir "$log" "OK" "${repo_name}: clonado (SSH)"
            else
                logger_escribir "$log" "INFO" "${repo_name}: SSH falló, reintentando con HTTPS"
                # Limpiar directorio parcial si quedó algo
                rm -rf "$repo_dir"
                salida=$(git clone --mirror "https://github.com/${repo_full}.git" "$repo_dir" 2>&1)

                if [[ $? -eq 0 ]]; then
                    logger_escribir "$log" "OK" "${repo_name}: clonado (HTTPS)"
                else
                    logger_escribir "$log" "ERROR" "${repo_name}: fallo al clonar con ambos protocolos - ${salida}"
                    errores=$((errores + 1))
                fi
            fi
        fi
    done <<< "$repos"

    if [[ $errores -gt 0 ]]; then
        logger_escribir "$log" "ERROR" "${errores} repo(s) fallaron"
        return 1
    fi

    logger_escribir "$log" "OK" "Todos los repos respaldados correctamente"
    return 0
}
