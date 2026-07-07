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
}
