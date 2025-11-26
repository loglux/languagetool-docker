# Self-hosted LanguageTool Server (Docker + fastText)

This repository contains a Dockerised setup for running a self-hosted [LanguageTool](https://languagetool.org/) HTTP server with:

- LanguageTool **6.6**
- Java 17 (JRE)
- Optional **fastText-based language detection** (using `lid.176.bin`)
- A small Bash script to build, (re)run and health-check the container

The server exposes the standard LanguageTool HTTP API at:

- `http://<YOUR_NAS_IP_OR_HOSTNAME>:9006/v2/check`

> Note: the exact host/IP is not hard-coded anywhere – you choose how to expose it (localhost only, LAN, etc.).

---

## Features

- Self-contained Docker image with:
  - Java 17 runtime
  - LanguageTool 6.6
  - fastText binary built from source
  - `lid.176.bin` language identification model
- Configured `server.properties` so LanguageTool uses fastText for language detection
- HTTP server bound to port **9006**
- `lt_manage.sh` script to:
  - build the Docker image
  - stop/remove any existing container
  - run a new container with `--restart always`
  - perform a simple health check using `curl`
- Ready to be used by other services (e.g. editors, note-taking apps, custom backends)

---

## Supported Languages

LanguageTool supports more than 30 languages and dialects; a full up-to-date list is maintained on the **Supported Languages** page:

https://dev.languagetool.org/languages

On that page you can see, for each language:

- Its language code (e.g. `en-US`, `en-GB`, `ru-RU`, `es`, etc.)  
- how many language-specific rules are available — which gives a rough indicator of how complete the grammar/style support is  

Because rule coverage varies wildly between languages (from full grammar/style checking to basic spell-checking), it’s recommended to consult the page above to check support level for a given language.


---

## Repository contents

- `Dockerfile`  
  Builds a LanguageTool 6.6 image with Java 17 and fastText support.

- `lt_manage.sh`  
  Convenience script to build and (re)deploy the container and verify that the server is responding.

---

## Requirements

- Docker installed and running on the host (NAS / server / PC)
- `curl` available on the host (for the health check in the script)
- At least:
  - ~2 GB of free RAM (the container uses `-Xmx2G` heap by default)
  - ~1–2 GB of disk space for the image (LanguageTool + Java + fastText model)

---

## Quick start

1. Clone this repository to your server / NAS.

2. Make the manage script executable:

```bash
   chmod +x lt_manage.sh
```

3. Run the script:
    
```bash
    ./lt_manage.sh
```
    
The script will:

- build the Docker image `local/languagetool:latest` from the `Dockerfile`;
	
- stop and remove any existing container named `languagetool`;
	
- run a new container:
	
	- name: `languagetool`
		
	- port mapping: `9006:9006`
		
	- restart policy: `--restart always`
		
- wait a few seconds and perform a health check against:
	
	- `http://localhost:9006/v2/check?language=en-US&text=test`
		

On success, you should see:
    
```text
    [SUCCESS] LanguageTool server is up and responding on port 9006.
```
    

---

## Accessing the server

### From the host

On the machine where Docker is running:

```bash
curl "http://localhost:9006/v2/check?language=en-US&text=This%20is%20a%20test"
```

You should receive a JSON response similar to:

```json
{
  "software": { "name": "LanguageTool", "version": "6.6", ... },
  "language": {
    "name": "English (US)",
    "code": "en-US",
    "detectedLanguage": {
      "name": "English (US)",
      "code": "en-US",
      "source": "fasttext",
      ...
    }
  },
  "matches": []
}
```

### From another machine on the network

Replace `<YOUR_NAS_IP>` with the IP or hostname of the host running the container:

```bash
curl "http://<YOUR_NAS_IP>:9006/v2/check?language=en-US&text=This%20is%20a%20test"
```

or using POST (recommended for real use):

```bash
curl -X POST \
  --data-urlencode "language=en-US" \
  --data-urlencode "text=This is a simple test." \
  "http://<YOUR_NAS_IP>:9006/v2/check"
```

---

## Configuration

### Java heap size

The `Dockerfile` starts LanguageTool with:

```dockerfile
CMD ["java", "-Xmx2G", "-cp", "languagetool-server.jar", "org.languagetool.server.HTTPServer", "--config", "server.properties", "--port", "9006", "--public", "--allow-origin", "*"]
```

- `-Xmx2G` – sets the maximum Java heap to 2 GB.
    
- Adjust this value if your host has less or more memory, e.g.:
    
    - `-Xmx1G`
        
    - `-Xmx4G`
        

After changing the `CMD` line, re-run:

```bash
./lt_manage.sh
```

to rebuild and restart the container.

### LanguageTool version

The `Dockerfile` uses:

```dockerfile
ENV LT_VERSION=6.6
```

If you want to pin to a different version (e.g. a newer release or snapshot), change this value to the desired version string and rebuild via `lt_manage.sh`.

> Be sure the download URL `https://languagetool.org/download/LanguageTool-${LT_VERSION}.zip` matches a real release or snapshot.

### Port

By default the container exposes port `9006` and the script maps it as:

```bash
-p 9006:9006
```

If you want to use a different host port, change `HOST_PORT` in `lt_manage.sh`:

```bash
HOST_PORT=9006
CONTAINER_PORT=9006
```

and adapt the `curl` commands accordingly.

### Network / security

The server is started with the `--public` flag:

```text
--public
```

This makes the LanguageTool HTTP server accessible from other hosts, which is convenient for LAN setups and external clients.

If you only want to allow local access:

- you can bind the port to `127.0.0.1` when running the container (instead of `0.0.0.0`);
    
- or restrict access using a firewall or reverse proxy.
    

For example, to bind only to localhost (if you prefer to run without the script):

```bash
docker run -d \
  --name languagetool \
  -p 127.0.0.1:9006:9006 \
  --restart always \
  local/languagetool:latest
```

---

## How fastText is integrated

The `Dockerfile`:

- clones the official fastText repository;
    
- patches `src/args.h` to add the missing `#include <cstdint>` (needed for stricter compilers on Alpine);
    
- builds the `fasttext` binary;
    
- downloads the `lid.176.bin` language identification model;
    
- writes these settings to `server.properties`:
    

```properties
fasttextModel=/opt/fasttext-model/lid.176.bin
fasttextBinary=/opt/fastText/fasttext
```

LanguageTool will then:

- use fastText for language detection whenever it needs to guess the language;
    
- still honour the `language=...` parameter if you pass it explicitly.
    

If you always specify `language=...` in your requests, fastText is not strictly required, but it improves automatic detection for mixed or unknown texts.

---

## Updating / rebuilding

Whenever you:

- change the `Dockerfile`, or
    
- want to update LanguageTool to a new version, or
    
- have modified configuration,
    

simply run:

```bash
./lt_manage.sh
```

The script will:

1. rebuild the image,
    
2. stop and remove the existing `languagetool` container,
    
3. start a new one,
    
4. run a health check.
    

---

## Troubleshooting

### `Error: Missing 'text' or 'data' parameter`

If you see this in response, the server is **working correctly** – it just means your request did not include any text to check. Make sure you always pass either:

- a `text` parameter, or
    
- a `data` parameter
    

for example:

```bash
curl "http://<YOUR_NAS_IP>:9006/v2/check?language=en-US&text=This%20is%20a%20test"
```

### Connection errors

- `Failed to connect` / `Connection refused`  
    Check that the container is running:
    
    ```bash
    docker ps -a | grep languagetool
    ```
    
    and inspect logs:
    
    ```bash
    docker logs languagetool | tail -n 50
    ```
    
- `Recv failure: Connection reset by peer`  
    This usually happens if the server is not yet fully started, or if it rejects external connections without `--public`. The provided Dockerfile and manage script already include `--public` and a health-check loop.
    

### fastText warnings

If you see:

```text
fastText not configured - language detection performance will be degraded
```

it means `LanguageTool` was started without `fastText` configuration. In this setup, the `Dockerfile` configures fastText automatically, so you should **not** see this warning once the new image is built and container is started via `lt_manage.sh`.

---

## Licence

`LanguageTool` and `fastText` have their own licences.  
This repository only provides a Docker-based integration around them. Please refer to the respective upstream projects for licence details.
