#!/usr/bin/env bash
set -euo pipefail

inventory=$(xcrun simctl list -j)
existing=$(jq -r '
  . as $inventory
  | [
      .runtimes[]
      | select(.isAvailable)
      | . as $runtime
      | ($inventory.devices[$runtime.identifier] // [])[]
      | select(.isAvailable and
          ((.name | startswith("iPhone Duo")) or
           ((.deviceTypeIdentifier // "") | startswith("com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"))))
      | {id: .udid, name: $runtime.name, version: ($runtime.version | split(".") | map(tonumber))}
    ]
  | sort_by(.version) | last // empty | [.id, .name] | @tsv
' <<< "$inventory")
if [[ -n "$existing" ]]; then
  IFS=$'\t' read -r simulator runtime_name <<< "$existing"
  printf 'Testing on iPhone Duo with %s\n' "$runtime_name" >&2
  printf '%s\n' "$simulator"
  exit
fi

device_type=$(jq -r '
  [.devicetypes[] | select(.name | startswith("iPhone Duo")) | .identifier][0] // empty
' <<< "$inventory")
runtimes=$(jq -r '
  [.runtimes[] | select(.isAvailable and (.identifier | contains(".iOS")))]
  | sort_by(.version | split(".") | map(tonumber)) | reverse
  | .[] | [.identifier, .name] | @tsv
' <<< "$inventory")
if [[ -n "$device_type" ]]; then
  while IFS=$'\t' read -r runtime runtime_name; do
    [[ -n "$runtime" ]] || continue
    if simulator=$(xcrun simctl create "Astral Key Test iPhone Duo" "$device_type" "$runtime"); then
      printf 'Testing on iPhone Duo with %s\n' "$runtime_name" >&2
      printf '%s\n' "$simulator"
      exit
    fi
  done <<< "$runtimes"
fi

printf 'No available iPhone Duo simulator could be selected or created.\n' >&2
xcrun simctl list runtimes >&2
xcrun simctl list devices available >&2
exit 1
