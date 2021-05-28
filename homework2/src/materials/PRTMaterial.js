class PRTMaterial extends Material {

    constructor(precomputeL, vertexShader, fragmentShader) {
        
        super({
            'uPrecomputeL': { type: '3fv', value: precomputeL},
        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);
        console.log(precomputeL);
    }
}

async function buildPRTMaterial(precomputeL, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(precomputeL, vertexShader, fragmentShader);

}