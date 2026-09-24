# Biblioteca comum dos scripts de teste (rodam no HOST e usam "kathara exec")
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_WIN="$(wslpath -w "$LAB_DIR")"
PASS=0; FAIL=0

C_OK="\033[32m"; C_NO="\033[31m"; C_T="\033[1;36m"; C_D="\033[0m"

# k <maquina> "<comando>"  -> executa dentro do no, devolve a saida e o codigo de retorno
k() {
  local m="$1"; shift
  local out rc
  out="$(kathara exec -d "$LAB_WIN" "$m" -- bash -c "$*" 2>/dev/null)"; rc=$?
  printf '%s\n' "${out//$'\r'/}"
  return $rc
}

titulo() { echo -e "\n${C_T}=== $* ===${C_D}"; }

# espera_ok <descricao> <maquina> <comando...>   -> o comando DEVE funcionar
espera_ok() {
  local desc="$1" m="$2"; shift 2
  local out; out="$(k "$m" "$@")"; local rc=$?
  if [ $rc -eq 0 ]; then
    echo -e "  ${C_OK}[PERMITIDO]${C_D} $desc"; PASS=$((PASS+1))
  else
    echo -e "  ${C_NO}[FALHOU   ]${C_D} $desc   <-- esperava-se que funcionasse"; FAIL=$((FAIL+1))
  fi
  [ -n "$VERBOSE" ] && echo "      \$ $* => rc=$rc | $out"
  return 0
}

# espera_bloqueio <descricao> <maquina> <comando...> -> o comando DEVE falhar
espera_bloqueio() {
  local desc="$1" m="$2"; shift 2
  local out; out="$(k "$m" "$@")"; local rc=$?
  if [ $rc -eq 0 ]; then
    echo -e "  ${C_NO}[PASSOU!! ]${C_D} $desc   <-- esperava-se BLOQUEIO"; FAIL=$((FAIL+1))
  else
    echo -e "  ${C_OK}[BLOQUEADO]${C_D} $desc"; PASS=$((PASS+1))
  fi
  [ -n "$VERBOSE" ] && echo "      \$ $* => rc=$rc | $out"
  return 0
}

resumo() {
  echo
  echo "-----------------------------------------------"
  echo " Resultado: $PASS conforme o esperado, $FAIL divergente(s)"
  echo "-----------------------------------------------"
  [ "$FAIL" -eq 0 ]
}

verifica_lab() {
  command -v kathara >/dev/null || { echo "kathara nao encontrado no PATH"; exit 1; }
  kathara exec -d "$LAB_WIN" fw -- true >/dev/null 2>&1 || {
    echo "Laboratorio nao esta em execucao. Rode:  kathara lstart -d $LAB_DIR --noterminals"; exit 1; }
}
