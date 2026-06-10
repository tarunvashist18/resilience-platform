#!/bin/bash

# ============================================================
#   RESILIENCE PLATFORM — LIVE TEST MONITOR
#   Shows exactly what is happening, test by test
# ============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

clear

print_header() {
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║         RESILIENCE TESTING PLATFORM — LIVE MONITOR          ║"
  echo "║              Real-Time Test Tracker                         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

print_header
echo -e "${YELLOW}  Waiting for a test to be submitted from the platform...${RESET}"
echo ""

DEPLOY_SEEN=false
CURRENT_IMAGE=""
LAST_CHAOS_TYPE=""

POD_CHAOS_DONE=false
CPU_STRESS_DONE=false
MEM_STRESS_DONE=false
NET_DELAY_DONE=false
PKT_LOSS_DONE=false
RECOVERY_DONE=false

reset_tests() {
  POD_CHAOS_DONE=false
  CPU_STRESS_DONE=false
  MEM_STRESS_DONE=false
  NET_DELAY_DONE=false
  PKT_LOSS_DONE=false
  RECOVERY_DONE=false
  LAST_CHAOS_TYPE=""
}

print_test_status() {
  echo ""
  echo -e "${WHITE}  ── TEST PROGRESS ─────────────────────────────────────────────${RESET}"

  if [ "$POD_CHAOS_DONE" = true ]; then
    echo -e "  ${GREEN} Pod Chaos Test       — PASS${RESET}"
  elif [ "$LAST_CHAOS_TYPE" = "pod" ]; then
    echo -e "  ${YELLOW} Pod Chaos Test       — RUNNING...${RESET}"
  else
    echo -e "  ${DIM}  ○ Pod Chaos Test       — waiting${RESET}"
  fi

  if [ "$CPU_STRESS_DONE" = true ]; then
    echo -e "  ${GREEN} CPU Stress Test      — PASS${RESET}"
  elif [ "$LAST_CHAOS_TYPE" = "cpu" ]; then
    echo -e "  ${YELLOW} CPU Stress Test      — RUNNING...${RESET}"
  else
    echo -e "  ${DIM}  ○ CPU Stress Test      — waiting${RESET}"
  fi

  if [ "$MEM_STRESS_DONE" = true ]; then
    echo -e "  ${GREEN} Memory Stress Test   — PASS${RESET}"
  elif [ "$LAST_CHAOS_TYPE" = "memory" ]; then
    echo -e "  ${YELLOW} Memory Stress Test   — RUNNING...${RESET}"
  else
    echo -e "  ${DIM}  ○ Memory Stress Test   — waiting${RESET}"
  fi

  if [ "$NET_DELAY_DONE" = true ]; then
    echo -e "  ${GREEN} Network Delay Test   — PASS${RESET}"
  elif [ "$LAST_CHAOS_TYPE" = "network" ]; then
    echo -e "  ${YELLOW} Network Delay Test   — RUNNING...${RESET}"
  else
    echo -e "  ${DIM}  ○ Network Delay Test   — waiting${RESET}"
  fi

  if [ "$PKT_LOSS_DONE" = true ]; then
    echo -e "  ${GREEN} Packet Loss Test     — PASS${RESET}"
  elif [ "$LAST_CHAOS_TYPE" = "packet" ]; then
    echo -e "  ${YELLOW} Packet Loss Test     — RUNNING...${RESET}"
  else
    echo -e "  ${DIM}  ○ Packet Loss Test     — waiting${RESET}"
  fi

  if [ "$RECOVERY_DONE" = true ]; then
    echo -e "  ${GREEN} Recovery Validation  — PASS${RESET}"
  else
    echo -e "  ${DIM}  ○ Recovery Validation  — waiting${RESET}"
  fi

  echo -e "${WHITE}  ───────────────────────────────────────────────────────────────${RESET}"
  echo ""
}

while true; do

  TIMESTAMP=$(date '+%H:%M:%S')
  RESILIENCE_PODS=$(kubectl get pods --no-headers 2>/dev/null | grep "resilience-" | grep -v "resilience-platform")
  CHAOS_OBJECTS=$(kubectl get podchaos,stresschaos,networkchaos -n chaos-testing --no-headers 2>/dev/null)

  if [ -n "$RESILIENCE_PODS" ] && [ "$DEPLOY_SEEN" = false ]; then
    DEPLOY_SEEN=true
    reset_tests
    CURRENT_IMAGE=$(echo "$RESILIENCE_PODS" | head -1 | awk '{print $1}' | sed 's/resilience-//' | sed 's/-[a-z0-9]*-[a-z0-9]*//')
    clear
    print_header
    echo -e "${GREEN}  [$TIMESTAMP]  NEW TEST STARTED${RESET}"
    echo -e "${WHITE}  Image: ${CYAN}${CURRENT_IMAGE}${RESET}"
    echo ""
  fi

  if [ "$DEPLOY_SEEN" = true ]; then

    clear
    print_header
    echo -e "${WHITE}  Image Under Test: ${CYAN}${CURRENT_IMAGE}${RESET}   ${DIM}[$TIMESTAMP]${RESET}"
    echo ""

    echo -e "${WHITE}  ── PODS ───────────────────────────────────────────────────────${RESET}"
    echo ""

    RUNNING_COUNT=0
    TOTAL_COUNT=0
    while IFS= read -r line; do
      if echo "$line" | grep -q "resilience-" && ! echo "$line" | grep -q "resilience-platform"; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        if echo "$line" | grep -q "Running"; then
          RUNNING_COUNT=$((RUNNING_COUNT + 1))
          echo -e "  ${GREEN} $line${RESET}"
        elif echo "$line" | grep -q "ContainerCreating\|Pending\|Init"; then
          echo -e "  ${YELLOW} $line${RESET}"
        elif echo "$line" | grep -q "Terminating"; then
          echo -e "  ${DIM} $line${RESET}"
        elif echo "$line" | grep -q "Error\|CrashLoop\|OOMKilled"; then
          echo -e "  ${RED} $line${RESET}"
        else
          echo -e "   $line"
        fi
      fi
    done <<< "$(kubectl get pods --no-headers 2>/dev/null)"

    echo ""
    echo -e "  ${WHITE}Pods Running: ${GREEN}${RUNNING_COUNT}${WHITE}/${TOTAL_COUNT}${RESET}"
    echo ""

    echo -e "${WHITE}  ── RESOURCE USAGE ─────────────────────────────────────────────${RESET}"
    echo ""
    TOP_OUTPUT=$(kubectl top pods 2>/dev/null | grep "resilience-" | grep -v "resilience-platform")
    if [ -n "$TOP_OUTPUT" ]; then
      while IFS= read -r line; do
        echo -e "  ${CYAN}$line${RESET}"
      done <<< "$TOP_OUTPUT"
    else
      echo -e "  ${DIM}  metrics not yet available...${RESET}"
    fi
    echo ""

    echo -e "${WHITE}  ── ACTIVE CHAOS ───────────────────────────────────────────────${RESET}"
    echo ""

    if [ -z "$CHAOS_OBJECTS" ]; then
      echo -e "  ${GREEN}   No active chaos — recovering or between tests${RESET}"
      if [ "$LAST_CHAOS_TYPE" = "pod" ] && [ "$POD_CHAOS_DONE" = false ]; then
        POD_CHAOS_DONE=true
      elif [ "$LAST_CHAOS_TYPE" = "cpu" ] && [ "$CPU_STRESS_DONE" = false ]; then
        CPU_STRESS_DONE=true
      elif [ "$LAST_CHAOS_TYPE" = "memory" ] && [ "$MEM_STRESS_DONE" = false ]; then
        MEM_STRESS_DONE=true
      elif [ "$LAST_CHAOS_TYPE" = "network" ] && [ "$NET_DELAY_DONE" = false ]; then
        NET_DELAY_DONE=true
      elif [ "$LAST_CHAOS_TYPE" = "packet" ] && [ "$PKT_LOSS_DONE" = false ]; then
        PKT_LOSS_DONE=true
      fi
    else
      while IFS= read -r line; do
        if echo "$line" | grep -q "pod-chaos"; then
          LAST_CHAOS_TYPE="pod"
          echo -e "  ${RED} POD KILL ACTIVE    → killing 1 pod, watching recovery${RESET}"
          echo -e "  ${DIM}   $line${RESET}"
        elif echo "$line" | grep -q "cpu-stress"; then
          LAST_CHAOS_TYPE="cpu"
          echo -e "  ${RED} CPU STRESS ACTIVE  → injecting 80% CPU load${RESET}"
          echo -e "  ${DIM}   $line${RESET}"
        elif echo "$line" | grep -q "memory-stress"; then
          LAST_CHAOS_TYPE="memory"
          echo -e "  ${RED} MEM STRESS ACTIVE  → injecting 256MB memory pressure${RESET}"
          echo -e "  ${DIM}   $line${RESET}"
        elif echo "$line" | grep -q "network-delay"; then
          LAST_CHAOS_TYPE="network"
          echo -e "  ${RED} NET DELAY ACTIVE   → injecting 3000ms latency${RESET}"
          echo -e "  ${DIM}   $line${RESET}"
        elif echo "$line" | grep -q "packet-loss"; then
          LAST_CHAOS_TYPE="packet"
          echo -e "  ${RED} PACKET LOSS ACTIVE → injecting 30% packet loss${RESET}"
          echo -e "  ${DIM}   $line${RESET}"
        fi
      done <<< "$CHAOS_OBJECTS"
    fi

    echo ""
    print_test_status

    echo -e "${WHITE}  ── RECENT EVENTS ──────────────────────────────────────────────${RESET}"
    echo ""
    kubectl get events --sort-by='.lastTimestamp' --no-headers 2>/dev/null \
      | grep "resilience-" | grep -v "resilience-platform" | tail -5 \
      | while IFS= read -r line; do
      if echo "$line" | grep -q "Killing\|Failed\|Error\|BackOff\|OOM"; then
        echo -e "  ${RED} $line${RESET}"
      elif echo "$line" | grep -q "Started\|Created\|Pulled\|Scheduled"; then
        echo -e "  ${GREEN} $line${RESET}"
      else
        echo -e "  ${DIM} $line${RESET}"
      fi
    done

    echo ""
    echo -e "  ${DIM}Refreshing every 2s... Ctrl+C to stop${RESET}"

    STILL_RUNNING=$(kubectl get pods --no-headers 2>/dev/null | grep "resilience-" | grep -v "resilience-platform")
    if [ -z "$STILL_RUNNING" ] && [ "$DEPLOY_SEEN" = true ]; then
      PKT_LOSS_DONE=true
      RECOVERY_DONE=true
      clear
      print_header
      echo -e "${GREEN}  [$TIMESTAMP] TEST COMPLETE — ${CURRENT_IMAGE}${RESET}"
      echo ""
      print_test_status
      echo -e "${GREEN}  All chaos experiments finished. Check the platform for scores.${RESET}"
      echo ""
      DEPLOY_SEEN=false
      reset_tests
      CURRENT_IMAGE=""
      echo -e "${YELLOW}  Waiting for next test submission...${RESET}"
      echo ""
    fi

  else
    echo -ne "\r${DIM}  [$TIMESTAMP] Waiting for image submission...${RESET}   "
  fi

  sleep 2

done
