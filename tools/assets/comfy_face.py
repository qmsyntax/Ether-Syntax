"""Paint a photographic face onto a head's depth map on Brent's ComfyUI server (FLUX.1-dev with the
union ControlNet in depth mode), for tools/assets/blender_face_gen.py:

    python tools/assets/comfy_face.py <dir with depth.png> male|female [seed] [--server http://host:8188]
        [--who "a 45-year-old man with a broad nose"] [--out face_f2.png]

Writes <dir>/face.png (or --out). --who replaces the person in the prompt (the framing, lighting
and shaved head stay). The person is generated, not anyone real: an adult, bald (hair is a separate
mesh in the game), evenly lit from the front so little lighting is baked into the skin.
"""
import json
import os
import sys
import time
import urllib.request
import uuid

PROMPTS = {
    "male": "close-up studio portrait photograph of a weathered 35-year-old man with a completely shaved bald head, "
            "facing the camera straight on, neutral expression, eyes open looking into the camera, clean-shaven, "
            "natural skin texture with visible pores and fine wrinkles, soft even diffuse light from the front, no harsh "
            "shadows, plain neutral grey background, bare shoulders, sharp focus, high detail",
    "female": "close-up studio portrait photograph of a 32-year-old woman with a completely shaved bald head, facing the "
              "camera straight on, neutral expression, eyes open looking into the camera, no makeup, natural skin "
              "texture with visible pores and a few freckles, soft even diffuse light from the front, no harsh "
              "shadows, plain neutral grey background, bare shoulders, sharp focus, high detail",
}


def post(server, path, data, ctype="application/json"):
    req = urllib.request.Request(server + path, data=data, headers={"Content-Type": ctype})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


def upload(server, path):
    boundary = uuid.uuid4().hex
    name = "passage_depth_%s.png" % uuid.uuid4().hex[:8]
    body = (b"--" + boundary.encode() + b"\r\nContent-Disposition: form-data; name=\"image\"; filename=\"" + name.encode()
            + b"\"\r\nContent-Type: image/png\r\n\r\n" + open(path, "rb").read() + b"\r\n--" + boundary.encode()
            + b"\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--" + boundary.encode() + b"--\r\n")
    return post(server, "/upload/image", body, "multipart/form-data; boundary=" + boundary)["name"]


def workflow(image, prompt, seed, strength=0.8):
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux1-dev-fp8.safetensors", "weight_dtype": "fp8_e4m3fn"}},
        "2": {"class_type": "DualCLIPLoader", "inputs": {"clip_name1": "clip_l.safetensors", "clip_name2": "t5xxl_fp8_e4m3fn.safetensors", "type": "flux"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 0]}},
        "5": {"class_type": "FluxGuidance", "inputs": {"conditioning": ["4", 0], "guidance": 3.0}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["2", 0]}},
        "7": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "flux-controlnet-union-pro.safetensors"}},
        "8": {"class_type": "SetUnionControlNetType", "inputs": {"control_net": ["7", 0], "type": "depth"}},
        "9": {"class_type": "LoadImage", "inputs": {"image": image}},
        "10": {"class_type": "ControlNetApplyAdvanced", "inputs": {"positive": ["5", 0], "negative": ["6", 0], "control_net": ["8", 0],
                                                                   "image": ["9", 0], "strength": strength, "start_percent": 0.0,
                                                                   "end_percent": 0.8, "vae": ["3", 0]}},
        "11": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "12": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "seed": seed, "steps": 28, "cfg": 1.0, "sampler_name": "euler",
                                                    "scheduler": "simple", "positive": ["10", 0], "negative": ["10", 1],
                                                    "latent_image": ["11", 0], "denoise": 1.0}},
        "13": {"class_type": "VAEDecode", "inputs": {"samples": ["12", 0], "vae": ["3", 0]}},
        "14": {"class_type": "SaveImage", "inputs": {"images": ["13", 0], "filename_prefix": "passage_face"}},
    }


FRAME = ("close-up studio portrait photograph of {who}, with a completely shaved bald head, facing the camera "
         "straight on, neutral expression, eyes open looking into the camera, no makeup, natural skin texture with "
         "visible pores, soft even diffuse light from the front, no harsh shadows, plain neutral grey background, "
         "bare shoulders, sharp focus, high detail")


def main():
    argv = sys.argv[1:]
    opts = {}
    for k in ("--server", "--who", "--out"):
        if k in argv:
            i = argv.index(k)
            opts[k] = argv[i + 1]
            del argv[i:i + 2]
    args = argv
    server = opts.get("--server", "http://192.168.1.53:8188")
    out_dir, sex = args[0], args[1]
    seed = int(args[2]) if len(args) > 2 else 7
    image = upload(server, os.path.join(out_dir, "depth.png"))
    prompt = FRAME.format(who=opts["--who"]) if "--who" in opts else PROMPTS[sex]
    pid = post(server, "/prompt", json.dumps({"prompt": workflow(image, prompt, seed), "client_id": "passage"}).encode())["prompt_id"]
    t0 = time.time()
    while True:
        time.sleep(3)
        with urllib.request.urlopen(server + "/history/" + pid, timeout=60) as r:
            hist = json.loads(r.read())
        if pid in hist:
            status = hist[pid].get("status", {})
            if status.get("status_str") == "error":
                print("COMFY error", json.dumps(status)[:800])
                sys.exit(1)
            outs = hist[pid].get("outputs", {})
            if "14" in outs:
                img = outs["14"]["images"][0]
                url = server + "/view?filename=%s&subfolder=%s&type=%s" % (img["filename"], img.get("subfolder", ""), img["type"])
                with urllib.request.urlopen(url, timeout=120) as r:
                    open(os.path.join(out_dir, opts.get("--out", "face.png")), "wb").write(r.read())
                print("COMFY %s in %.0f s (seed %d)" % (opts.get("--out", "face.png"), time.time() - t0, seed))
                return
        if time.time() - t0 > 900:
            print("COMFY timed out")
            sys.exit(1)


if __name__ == "__main__":
    main()
