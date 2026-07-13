# AI / LLM log-ingest ports — one dedicated Cribl TCP-JSON receiver per source
# family, HAProxy-fronted (LB to the Cribl Stream pair, mirroring the claude S2S
# path). Cribl best practice is a dedicated port per source so routing is by
# listener, not payload inspection. The backend flow reuses the existing
# cribl_s2s (10300) receiver on Stream; these frontends are opened on the
# pipeline (HAProxy) containers by the ai-log-ingest security group.
#
# Split into its own file (referenced from constants.tf as local.ai_log_ports)
# so constants.tf stays under the shared _file-size 12 KB error threshold;
# locals merge across files in the module. The Splunk index each lands in is
# noted inline; new indexes (codex, openbao_audit) are created in ansible-splunk
# in a later phase — see the WS3-max tracking issue.
locals {
  ai_log_ports = {
    claude_code    = 10311 # MacBook claude-code IO logs      -> index=claude
    codex_cli      = 10312 # MacBook codex CLI logs           -> index=codex (new)
    agy_cli        = 10313 # MacBook agy/antigravity CLI logs -> index=gemini
    copilot_cli    = 10314 # MacBook GitHub Copilot logs      -> index=openai
    vscode         = 10315 # VS Code telemetry                -> index=vscode
    macstudio_llm  = 10321 # Mac Studio llama-swap + vllm-mlx -> index=llm
    macstudio_gate = 10322 # Mac Studio caddy LLM-gate access -> index=llm
    homelab_llm    = 10323 # homelab llama_cpp + llm_router   -> index=llm
    openbao_audit  = 10331 # OpenBao file audit device        -> index=openbao_audit (new)
  }

  # Splunk landing zone per source, keyed to the SAME names as ai_log_ports so
  # the two maps cannot drift apart (ai_log_routing derives its port from
  # ai_log_ports; a name mismatch is a plan-time error). This is the single
  # routing truth the downstream repos consume via ansible_inventory.constants:
  # HAProxy renders one frontend per entry, Cribl Stream one tcpjson/syslog
  # input per entry, and the ai_stamp pipeline stamps index/sourcetype from it.
  # ai_log_ports itself stays map(number) — the firewall module types it, and
  # it is already applied — so the routing metadata lives in this additive map.
  ai_log_index_map = {
    claude_code    = { index = "claude", sourcetype = "claude:code" }
    codex_cli      = { index = "codex", sourcetype = "codex:cli" }
    agy_cli        = { index = "gemini", sourcetype = "antigravity:cli" }
    copilot_cli    = { index = "openai", sourcetype = "copilot:cli" }
    vscode         = { index = "vscode", sourcetype = "vscode:telemetry" }
    macstudio_llm  = { index = "llm", sourcetype = "llamaswap" }
    macstudio_gate = { index = "llm", sourcetype = "caddy:access" }
    homelab_llm    = { index = "llm", sourcetype = "llamaswap" }
    openbao_audit  = { index = "openbao_audit", sourcetype = "openbao:audit" }
  }

  ai_log_routing = {
    for name, port in local.ai_log_ports : name => {
      port       = port
      index      = local.ai_log_index_map[name].index
      sourcetype = local.ai_log_index_map[name].sourcetype
    }
  }
}
