(* ::Package:: *)

SetDirectory@NotebookDirectory[];
Needs["MXNetLink`"]
Needs["NeuralNetworks`"]
DateString[]


(* ::Subitem:: *)
(*Tue 16 Oct 2018 20:31:45*)


(* ::Subchapter:: *)
(*Import Weights*)


params = NDArrayImport["cifar_wideresnet16_10-0000.params"];


(* ::Subchapter:: *)
(*Encoder & Decoder*)


mShift = {0.485, 0.456, 0.406};
vShift = {0.229, 0.224, 0.225}^2;
encoder = NetEncoder[{"Image", 32, "MeanImage" -> mShift, "VarianceImage" -> vShift}]
tags = {"airplane", "automobile", "bird", "cat", "deer", "dog", "frog", "horse", "ship", "truck"};
decoder = NetDecoder[{"Class", tags}]


(* ::Subchapter:: *)
(*Pre-defined Structure*)


getBN[i_, j_] := BatchNormalizationLayer[
	"Epsilon" -> 1*^-5,
	"Beta" -> params["arg:cifarwideresnet0_stage" <> i <> "_batchnorm" <> j <> "_beta"],
	"Gamma" -> params["arg:cifarwideresnet0_stage" <> i <> "_batchnorm" <> j <> "_gamma"],
	"MovingMean" -> params["aux:cifarwideresnet0_stage" <> i <> "_batchnorm" <> j <> "_running_mean"],
	"MovingVariance" -> params["aux:cifarwideresnet0_stage" <> i <> "_batchnorm" <> j <> "_running_var"]
]
getBN2[j_] := BatchNormalizationLayer[
	"Epsilon" -> 1*^-5,
	"Beta" -> params["arg:cifarwideresnet0_batchnorm" <> j <> "_beta"],
	"Gamma" -> params["arg:cifarwideresnet0_batchnorm" <> j <> "_gamma"],
	"MovingMean" -> params["aux:cifarwideresnet0_batchnorm" <> j <> "_running_mean"],
	"MovingVariance" -> params["aux:cifarwideresnet0_batchnorm" <> j <> "_running_var"]
]
getCN[i_, j_, p_ : 1, s_ : 1] := ConvolutionLayer[
	"Weights" -> params["arg:cifarwideresnet0_stage" <> i <> "_conv" <> j <> "_weight"],
	"Biases" -> None, "PaddingSize" -> p, "Stride" -> s
]
getCN2[j_] := ConvolutionLayer[
	"Weights" -> params["arg:cifarwideresnet0_conv" <> j <> "_weight"],
	"Biases" -> None, "PaddingSize" -> 1
]
getBlock[i_, j_, k_ : 0] := NetGraph[{
	getBN[ToString[i], ToString[j]], Ramp, getCN[ToString[i], ToString[j + k]],
	getBN[ToString[i], ToString[j + 1]], Ramp, getCN[ToString[i], ToString[j + 1 + k]],
	ThreadingLayer[Plus]
}, {
	NetPort["Input"] -> 7,
	NetPort["Input"] -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7
}]
getBlock2[i_] := NetGraph[{
	getBN[ToString[i], "0"], Ramp, getCN[ToString[i], "2", 0, 1], ThreadingLayer[Plus],
	getCN[ToString[i], "0"], getBN[ToString[i], "1"], Ramp, getCN[ToString[i], "1"]
}, {
	NetPort["Input"] -> 1 -> 2 -> 3 -> 4,
	2 -> 5 -> 6 -> 7 -> 8 -> 4
}]
getBlock3[i_] := NetGraph[{
	getBN[ToString[i], "0"], Ramp, getCN[ToString[i], "2", 0, 2], ThreadingLayer[Plus],
	getCN[ToString[i], "0", 1, 2], getBN[ToString[i], "1"], Ramp, getCN[ToString[i], "1"]
}, {
	NetPort["Input"] -> 1 -> 2 -> 3 -> 4,
	2 -> 5 -> 6 -> 7 -> 8 -> 4
}]
getBlock4[] := NetChain[{
	getBN2["2"], Ramp,
	AggregationLayer[Mean]
}]


(* ::Subchapter:: *)
(*Main*)


mainNet = NetChain[{
	NetChain[{getBN2["0"] , getCN2["0"], getBN2["1"]}],
	getBlock2[1],
	Table[getBlock[1, 2, 1], {i, 2, 2, 2}],
	getBlock3[2],
	Table[getBlock[2, i, 1], {i, 2, 2, 2}],
	getBlock3[3],
	Table[getBlock[3, i, 1], {i, 2, 2, 2}],
	getBlock4[],
	LinearLayer[10,
		"Weights" -> params["arg:cifarwideresnet0_dense0_weight"],
		"Biases" -> params["arg:cifarwideresnet0_dense0_bias"]
	],
	SoftmaxLayer[]
} // Flatten,
	"Input" -> encoder,
	"Output" -> decoder
]


(* ::Subchapter:: *)
(*Export Model*)


Export["cifar_wideresnet16_10.WXF", mainNet]