import torchxrayvision as xrv
import skimage, torch, torchvision
import sys
import argparse

# Parse command-line arguments
parser = argparse.ArgumentParser(description='Process X-ray images')
parser.add_argument('image_path', help='Path to the input image')
parser.add_argument('-resize', action='store_true', help='Resize the image')
args = parser.parse_args()

# Prepare the image:
img = skimage.io.imread(args.image_path)
img = xrv.datasets.normalize(img, 255) # convert 8-bit image to [-1024, 1024] range

# Handle both grayscale (2D) and color (3D) images
if len(img.shape) == 3:
    img = img.mean(2) # Make single color channel for RGB images
img = img[None, ...] # Add channel dimension

transform = torchvision.transforms.Compose([xrv.datasets.XRayCenterCrop(),xrv.datasets.XRayResizer(224)])

img = transform(img)
img = torch.from_numpy(img)

# Load model and process image
model = xrv.models.DenseNet(weights="densenet121-res224-all")
outputs = model(img[None,...]) # or model.features(img[None,...]) 

# Print results
results = dict(zip(model.pathologies, outputs[0].detach().numpy()))
print(f"\nProcessing image: {args.image_path}")
print("\nPathology predictions:")
for pathology, score in sorted(results.items(), key=lambda x: x[1], reverse=True):
    print(f"  {pathology}: {score:.6f}")
