import os
import subprocess

# Path to the trained YOLOv11 .pt model (already placed in the repo root)
MODEL_PT = os.path.abspath(os.path.join(os.path.dirname(__file__), "kabadiai_best.pt"))

# Output directory for exported assets (Flutter expects assets/model/)
EXPORT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../kabadiai_app/assets/model"))
os.makedirs(EXPORT_DIR, exist_ok=True)

# Ultralytics export command – produces a TFLite model among other formats.
# We use the CLI utility; ensure ultralytics is installed in the venv.
cmd = ["python", "-m", "ultralytics", "export", f"model={MODEL_PT}", "format=tflite", "device=cpu", f"project={EXPORT_DIR}", "name=kabadiai"]

print(f"Running export: {' '.join(cmd)}")
subprocess.run(cmd, check=True)

print("✅ Export completed. TFLite model saved at:")
print(os.path.join(EXPORT_DIR, "kabadiai.tflite"))
