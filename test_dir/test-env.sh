#!/bin/bash
set -e

echo "Starting rigorous AI-Sheath tests..."
echo "------------------------------------"

# Clean up
rm -rf test_playground
mkdir -p test_playground
cd test_playground

# Set up test files
touch a.txt b.txt c.txt d.txt "space file.txt"
# Mock kubectl for testing
echo '#!/bin/bash' > kubectl
echo 'echo "Mock kubectl executed with args: $@"' >> kubectl
chmod +x kubectl
export PATH="$PWD:$PATH"

echo "[Test 1] Standard un-sheathed command (should succeed)"
bash ../../src/cs -c "ls -la > output_ls.txt"
if [[ ! -f output_ls.txt ]]; then echo "FAIL 1"; exit 1; fi

echo "[Test 2] Basic tracked command without justify (should fail)"
if bash ../../src/cs -c "rm a.txt" 2>/dev/null; then
    echo "FAIL 2: rm succeeded without justify!"
    exit 1
fi
if [[ ! -f a.txt ]]; then echo "FAIL 2: file was deleted contextually!"; exit 1; fi

echo "[Test 3] Basic tracked command WITH !override! justify (should succeed)"
bash ../../src/cs -c "rm a.txt --sheathJustify '!override!'"
if [[ -f a.txt ]]; then echo "FAIL 3: a.txt still exists!"; exit 1; fi

echo "[Test 4] Subshells and Chains (should fail on rm)"
if bash ../../src/cs -c "touch sub.txt && (ls; rm sub.txt) || echo 'failed'" 2>/dev/null; then
    :
fi
if [[ ! -f sub.txt ]]; then echo "FAIL 6: rm inside subshell executed!"; exit 1; fi

echo "[Test 7] Command substitution execution (should fail on rm)"
if bash ../../src/cs -c 'CMD="rm c.txt"; $CMD' 2>/dev/null; then
    echo "FAIL 7: command substitution bypassed sheath!"
    exit 1
fi
if [[ ! -f c.txt ]]; then echo "FAIL 7: file deleted by sub!"; exit 1; fi

echo "[Test 8] Command substitution WITH justify (should succeed)"
bash ../../src/cs -c 'CMD="rm c.txt --sheathJustify !override!"; $CMD'
if [[ -f c.txt ]]; then echo "FAIL 8: variable substitution failed to delete!"; exit 1; fi

echo "[Test 9] Spaces in arguments (should succeed securely)"
bash ../../src/cs -c "rm 'space file.txt' --sheathJustify '!override!'"
if [[ -f "space file.txt" ]]; then echo "FAIL 9: space argument rm failed!"; exit 1; fi

echo "[Test 10] Conditional kubectl delete without justify (should fail)"
if bash ../../src/cs -c "kubectl delete pod my-pod" 2>/dev/null; then
    echo "FAIL 10: kubectl delete succeeded without justify!"
    exit 1
fi

echo "[Test 11] Conditional kubectl get without justify (should succeed)"
bash ../../src/cs -c "kubectl get pods > output_kubectl.txt"
if [[ ! -f output_kubectl.txt ]]; then echo "FAIL 11: kubectl get was blocked!"; exit 1; fi

echo "[Test 12] Conditional kubectl delete WITH !override! justify (should succeed)"
bash ../../src/cs -c "kubectl delete pod my-pod --sheathJustify '!override!' > output_kubectl_del.txt"
if [[ ! -f output_kubectl_del.txt ]]; then echo "FAIL 12: kubectl delete with override was blocked!"; exit 1; fi

echo "[Test 13] Interactive login shell flag routing (-il) (should route to bash)"
# Piping echo into an interactive login proxy
echo "echo hello from proxy" | bash ../../src/cs -il > output_interactive.txt
if ! grep -q "hello from proxy" output_interactive.txt; then echo "FAIL 13: -il flag did not route to interactive bash!"; exit 1; fi

echo "[Test 14] Empty argument shell routing (should route to bash)"
# Piping echo into the proxy with no arguments
echo "echo hello from empty args" | bash ../../src/cs > output_empty.txt
if ! grep -q "hello from empty args" output_empty.txt; then echo "FAIL 14: empty argument invocation did not route to bash!"; exit 1; fi

echo "[Test 15] Test subshell environment injection via BASH_ENV (should fail on rm)"
# Test that tracking survives bash spawning *another* bash
if bash ../../src/cs -c "bash -c 'rm d.txt'" 2>/dev/null; then
    echo "FAIL 15: nested bash substitution bypassed sheath!"
    exit 1
fi
if [[ ! -f d.txt ]]; then echo "FAIL 15: file deleted by nested bash!"; exit 1; fi

echo "------------------------------------"
echo "✅ All tests PASSED!"
cd ..
rm -rf test_playground
