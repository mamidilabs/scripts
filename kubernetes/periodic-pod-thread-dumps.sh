#!/bin/bash

# Usage: ./periodic-pod-thread-dumps.sh <pod-name> [namespace]

POD_NAME="$1"   # Pod name from first argument
NAMESPACE="${2:-default}"  # Namespace from second argument or default
INTERVAL=5                 # Interval in seconds
COUNT=5                    # Number of dumps
REMOTE_DIR="/tmp/thread_dumps_${POD_NAME}_$$"

if [ -z "$POD_NAME" ]; then
  echo "Usage: $0 <pod-name> [namespace]"
  exit 1
fi

# Create remote directory in pod
kubectl exec -n $NAMESPACE $POD_NAME -- mkdir -p "$REMOTE_DIR"

for i in $(seq 1 $COUNT); do
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  kubectl exec -n $NAMESPACE $POD_NAME -- sh -c "jstack 1 > $REMOTE_DIR/thread_dump_$TIMESTAMP.txt"
  echo "Thread dump $i saved in pod as $REMOTE_DIR/thread_dump_$TIMESTAMP.txt"
  if [ $i -lt $COUNT ]; then
    sleep $INTERVAL
  fi
done

# Create a local directory for dumps
LOCAL_DIR="thread_dumps_${POD_NAME}_$(date +"%Y%m%d_%H%M%S")"
mkdir -p "$LOCAL_DIR"

# Copy all thread dump files from pod to local directory
kubectl cp "$NAMESPACE/$POD_NAME:$REMOTE_DIR" "$LOCAL_DIR"
echo "All thread dumps have been copied from pod to $LOCAL_DIR/"

# download heap dumps
HEAP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
kubectl exec -n $NAMESPACE $POD_NAME -- sh -c "jmap -dump:live,format=b,file=$REMOTE_DIR/heap_dump_${HEAP_TIMESTAMP}.hprof 1"
echo "Heap dump saved in pod as $REMOTE_DIR/heap_dump_${HEAP_TIMESTAMP}.hprof"
kubectl cp "$NAMESPACE/$POD_NAME:$REMOTE_DIR/heap_dump_${HEAP_TIMESTAMP}.hprof" "$LOCAL_DIR/heap_dump_${HEAP_TIMESTAMP}.hprof"
echo "Heap dump copied to local directory $LOCAL_DIR/"