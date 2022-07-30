using System.Collections;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class IndirectSH : MonoBehaviour
{
    [Range(0, 2)]
    public float intensity = 1;
    public Cubemap input_cubemap;
    public Vector4[] coefficients;

    private void Update()
    {
        for (int i = 0; i < 9; ++i)
        {
            Shader.SetGlobalVector("c" + i.ToString(), coefficients[i]*intensity);
        }
    }
}

#if UNITY_EDITOR
[CustomEditor(typeof(IndirectSH))]
public class IndirectSHEditor : Editor 
{
    private Vector4[]   coefficients;

    public override void OnInspectorGUI() 
    {
        base.OnInspectorGUI();

        IndirectSH indirectSH = target as IndirectSH;
        
        if (indirectSH.input_cubemap != null)
        {
            EditorGUILayout.Space();

            if (GUILayout.Button("CPU Uniform 9 Coefficients"))
            {
                coefficients = new Vector4[9];
                if (SphericalHarmonics.CPU_Project_Uniform_9Coeff(indirectSH.input_cubemap, coefficients))
                {
                    for (int i = 0; i < 9; ++i)
                    {
                        Shader.SetGlobalVector("c" + i.ToString(), coefficients[i]*indirectSH.intensity);
                    }
                    indirectSH.coefficients = coefficients;
                    
                    SceneView.RepaintAll();
                }
            }

            EditorGUILayout.Space();

            if (GUILayout.Button("CPU Monte Carlo 9 Coefficients"))
            {
                coefficients = new Vector4[9];
                if (SphericalHarmonics.CPU_Project_MonteCarlo_9Coeff(indirectSH.input_cubemap, coefficients, 4096))
                {
                    for (int i = 0; i < 9; ++i)
                    {
                        Shader.SetGlobalVector("c" + i.ToString(), coefficients[i]*indirectSH.intensity);
                    }
                    indirectSH.coefficients = coefficients;

                    SceneView.RepaintAll();
                }
            }

            EditorGUILayout.Space();

            if (GUILayout.Button("GPU Uniform 9 Coefficients"))
            {
                coefficients = new Vector4[9];
                if (SphericalHarmonics.GPU_Project_Uniform_9Coeff(indirectSH.input_cubemap, coefficients))
                {
                    for (int i = 0; i < 9; ++i)
                    {
                        Shader.SetGlobalVector("c" + i.ToString(), coefficients[i]*indirectSH.intensity);
                    }
                    indirectSH.coefficients = coefficients;

                    SceneView.RepaintAll();
                }
            }

            EditorGUILayout.Space();

            if (GUILayout.Button("GPU Monte Carlo 9 Coefficients"))
            {
                coefficients = new Vector4[9];
                
                if (SphericalHarmonics.GPU_Project_MonteCarlo_9Coeff(indirectSH.input_cubemap, coefficients))
                {
                    for (int i = 0; i < 9; ++i)
                    {
                        Shader.SetGlobalVector("c" + i.ToString(), coefficients[i]*indirectSH.intensity);
                    }
                    indirectSH.coefficients = coefficients;

                    SceneView.RepaintAll();
                }
            }
        }
    }
}
#endif