# Key Features:

1. Connectivity Check: Checks if the host is reachable before attempting to connect
2. Resource Auto-Detect: Runs showmount -e and parses the output
3. Interactive Selection: Allows you to choose which resource to mount from a numbered list
4. Fallback Mount: Attempts a standard mount first, then NFSv3 for compatibility
5. Error Handling: Includes checks and informative error messages
6. Colors: Colored output for better readability
7. Mount Information: Displays details of a successful mount

# Additional Features:

Dependency Checking: Verifies that showmount, mount, and ping are available

Automatic Cleanup: Automatically unmounts if anything is already mounted in /tmp/nfs_mount

Detailed Information: Displays the available space and contents of the mounted directory

Robust Error Handling: Includes multiple checks and informational messages

# How to use nfs_mount:

**With IP only (default port)**
```
./smart_nfs.sh 10.129.155.148
```
**With custom IP and port**
```
./smart_nfs.sh 10.129.155.148 2049
```
**For unmount**
```
./smart_nfs.sh --unmount
```

Then you can enter: 10.129.155.148 or 10.129.155.148:2049

<img width="648" height="533" alt="Captura de pantalla 2026-05-18 113501" src="https://github.com/user-attachments/assets/b102d6b3-33c8-43fd-a4f2-7013941b8a62" />


