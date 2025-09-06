source ./os.sh
source ./assert.sh

echo "Detected: $(os::id) $(os::version) $(os::arch)"

# Hard stop if not Debian family
assert::os_family debian   # uses fatal

# Allow caller to handle error
if ! assert::os_id ubuntu; then
  echo "Not Ubuntu, but continuing..."
fi

# Just warn
assert::arch x86_64

echo "✅ Reached main script"