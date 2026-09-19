# Repository Description

This repo contains code for the 284 final project. Artifacts should be placed in the 284FinalProject google drive.

## training

training currently holds the files for part 1 and part 2 VGG16 training, including modified files `vgg_quant.py` and `quant_layer.py` that must be swapped out in the original ece284 folder for successful training. Status on related tasks are:

- [x] 4 bit activation 4 bit weight quantization > 90%
- [x] 2 bit activation 4 bit weight quantization > 90% (currently hitting 88.5%)

Links to the respective weights are:

[4bit Activation >90%](https://drive.google.com/file/d/1nl0Q7PixA0p5ObYYcjTe8l8sOuuUKrn6/view?usp=drive_link)

[2bit Activation >90%](https://drive.google.com/file/d/1AFsIBO4dC6t-hkLGNMKFh9DvY_bfjYn6/view?usp=drive_link)