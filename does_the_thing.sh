#!/bin/bash
set -x
## the input files
echo "x,y,z,t,label"> coords.csv

for line in $(jq -r .coords config.json)
do
	echo $line
	echo $line,0,0 >> coords.csv
done

SUBBRAIN=$(jq -r .t1 config.json)
SUBMASK=$(jq -r .mask config.json)

MNI=/HCPpipelines/global/templates/MNI152_T1_1mm_brain.nii.gz
MSK=/HCPpipelines/global/templates/MNI152_T1_1mm_brain_mask.nii.gz

## skull strip the T1
## (at the very least you need a brain mask)
#echo "Skull stripping brain and creating brain mask..."
#bet ${SUB}.nii.gz brain -R -B

## N4 bias correction
#antsAtroposN4.sh -d 3 -a brain.nii.gz -x brain_mask.nii.gz -c 3 -o brain_bias

## compute the registration
echo "Computing linear / non-linear alignment of input brain to MNI space..."
antsRegistration --dimensionality 3 --float 0 -x [$MSK,$SUBMASK] \
		 --output [t1_to_mni_,t1_to_mni_Warped.nii.gz] \
		 --interpolation Linear \
		 --winsorize-image-intensities [0.005,0.995] \
		 --use-histogram-matching 0 \
		 --initial-moving-transform [$MNI,$SUBBRAIN,1] \
		 --transform Rigid[0.1] \
		 --metric MI[$MNI,$SUBBRAIN,1,32,Regular,0.25] \
		 --convergence [1000x500x250x100,1e-6,10] \
		 --shrink-factors 8x4x2x1 \
		 --smoothing-sigmas 3x2x1x0vox \
		 --transform Affine[0.1] \
		 --metric MI[$MNI,$SUBBRAIN,1,32,Regular,0.25] \
		 --convergence [1000x500x250x100,1e-6,10] \
		 --shrink-factors 8x4x2x1 \
		 --smoothing-sigmas 3x2x1x0vox \
		 --transform SyN[0.1,3,0] \
		 --metric CC[$MNI,$SUBBRAIN,1,4] \
		 --convergence [100x70x50x20,1e-6,10] \
		 --shrink-factors 8x4x2x1 \
		 --smoothing-sigmas 3x2x1x0vox  

## apply a transform to move coordinates to subject space (?)

## linear transform
echo "Converting points from MNI space to subject space w/ linear warp..."
antsApplyTransformsToPoints -d 3 -i coords.csv -o sub_aff_coords.csv -t [t1_to_mni_0GenericAffine.mat,1]

## non-linear transform
echo "Converting points from MNI space to subject space w/ linear and non-linear warp..."
antsApplyTransformsToPoints -d 3 -i coords.csv -o sub_wrp_coords.csv -t [t1_to_mni_1InverseWarp.nii.gz,0] -t [t1_to_mni_0GenericAffine.mat,1]

echo "Done."
