cd $L_SDR_DIR
echo "=== PWD ==="
pwd

echo ""
echo "=== Root .bash files ==="
find . -maxdepth 1 -type f -name "*.bash" 2>/dev/null | head -5

echo ""
echo "=== Root .sh files ==="
find . -maxdepth 1 -type f -name "*.sh" 2>/dev/null | head -5

echo ""
echo "=== scripts/*.py files ==="
find scripts -maxdepth 1 -type f -name "*.py" 2>/dev/null | head -5

echo ""
echo "=== tests/*.py files ==="
find tests -maxdepth 1 -type f -name "*.py" 2>/dev/null | head -5

echo ""
echo "=== utils/*.bash files ==="
find utils -maxdepth 1 -type f -name "*.bash" 2>/dev/null | head -5

echo ""
echo "=== Testing glob directly ==="
ls *.bash 2>/dev/null | head -3

echo ""
echo "=== Directory list ==="
ls -ld */ 2>/dev/null