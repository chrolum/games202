class PRTMaterial extends Material {

    constructor(precomputeL, precomputeLT, vertexShader, fragmentShader) {

        super({
            // 'uPrecomputeL': { type: 'texture', value: precomputeL },
        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);
    }
}

async function buildPRTMaterial(precomputeL, precomputeLT, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(precomputeL, precomputeLT, vertexShader, fragmentShader);

}