#!/bin/bash
#
# Test latency script for Macula pub/sub system
# Runs inside the container's existing Erlang VM via release eval
#
# Usage:
#   ./scripts/test-latency.sh [container] [num_messages]
#
# Examples:
#   ./scripts/test-latency.sh dev-peer1 20
#   ./scripts/test-latency.sh dev-peer2 50
#

set -e

CONTAINER=${1:-dev-peer1}
NUM_MESSAGES=${2:-20}
TOPIC="latency.test.$(date +%s)"

echo "=============================================="
echo "MACULA LATENCY TEST - BASELINE"
echo "=============================================="
echo "Container:    $CONTAINER"
echo "Messages:     $NUM_MESSAGES"
echo "Topic:        $TOPIC"
echo "=============================================="
echo ""

# First, check if the container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "ERROR: Container $CONTAINER is not running"
    echo "Start containers with: docker compose up -d"
    exit 1
fi

echo "Running latency test..."
echo ""

# Execute using the release eval command with Elixir syntax
docker exec "$CONTAINER" /home/app/bin/macula_arcade eval "
  IO.puts \"\"
  IO.puts \"=== MACULA PUBSUB LATENCY TEST ===\"
  IO.puts \"Topic: $TOPIC\"
  IO.puts \"Messages: $NUM_MESSAGES\"
  IO.puts \"\"

  # Find local client
  case Process.whereis(:macula_local_client) do
    nil ->
      IO.puts \"ERROR: macula_local_client not running\"
      {:error, :no_client}

    client ->
      IO.puts \"Found local client: #{inspect(client)}\"

      # Create ETS to store received timestamps
      tab = :ets.new(:latency_results, [:set, :public])

      # Track our test messages
      test_pid = self()

      # Subscribe to topic
      topic = \"$TOPIC\"
      IO.puts \"Subscribing to #{topic}...\"

      :ok = :macula.subscribe(client, topic, fn _t, payload ->
        recv_time = :erlang.system_time(:microsecond)
        case Map.get(payload, \"test_id\") do
          nil -> :ok
          id ->
            :ets.insert(tab, {id, recv_time})
            send(test_pid, {:msg_received, id})
        end
      end)

      # Wait for subscription to propagate
      IO.puts \"Waiting 2s for subscription propagation...\"
      Process.sleep(2000)

      # Publish messages with timestamps
      IO.puts \"Publishing $NUM_MESSAGES messages...\"
      send_times = Enum.map(1..$NUM_MESSAGES, fn n ->
        send_time = :erlang.system_time(:microsecond)
        payload = %{\"test_id\" => n, \"sent_at\" => send_time}
        :macula.publish(client, topic, payload)
        Process.sleep(100)  # 100ms between messages
        {n, send_time}
      end)

      IO.puts \"Waiting 5s for messages to arrive...\"
      Process.sleep(5000)

      # Collect results
      latencies = Enum.flat_map(send_times, fn {id, send_time} ->
        case :ets.lookup(tab, id) do
          [{^id, recv_time}] -> [recv_time - send_time]
          [] -> []
        end
      end)

      :ets.delete(tab)

      num_recv = length(latencies)
      IO.puts \"\"
      IO.puts \"=== RESULTS ===\"
      IO.puts \"Received: #{num_recv} / $NUM_MESSAGES messages\"

      case latencies do
        [] ->
          IO.puts \"\"
          IO.puts \"No messages received - check pubsub routing\"

        _ ->
          min_lat = Enum.min(latencies)
          max_lat = Enum.max(latencies)
          avg_lat = Enum.sum(latencies) / length(latencies)
          sorted = Enum.sort(latencies)
          len = length(sorted)
          p50_idx = max(0, div(len, 2) - 1)
          p95_idx = max(0, round(len * 0.95) - 1)
          p50 = Enum.at(sorted, p50_idx, 0)
          p95 = Enum.at(sorted, p95_idx, 0)

          IO.puts \"\"
          IO.puts \"--- Latency (microseconds) ---\"
          :io.format(\"Min:  ~8.0f us  (~6.2f ms)~n\", [min_lat * 1.0, min_lat / 1000])
          :io.format(\"Max:  ~8.0f us  (~6.2f ms)~n\", [max_lat * 1.0, max_lat / 1000])
          :io.format(\"Avg:  ~8.0f us  (~6.2f ms)~n\", [avg_lat, avg_lat / 1000])
          :io.format(\"P50:  ~8.0f us  (~6.2f ms)~n\", [p50 * 1.0, p50 / 1000])
          :io.format(\"P95:  ~8.0f us  (~6.2f ms)~n\", [p95 * 1.0, p95 / 1000])

          # Calculate throughput
          total_time = max_lat  # Time from first send to last receive
          throughput = num_recv / (total_time / 1_000_000)
          :io.format(\"~nThroughput: ~.1f msg/sec~n\", [throughput])
      end

      IO.puts \"\"
      IO.puts \"=== TEST COMPLETE ===\"
      IO.puts \"\"
      :ok
  end
"

echo ""
echo "=============================================="
