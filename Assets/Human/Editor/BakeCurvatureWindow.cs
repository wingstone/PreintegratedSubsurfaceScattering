using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using System.IO;
using System.Runtime.InteropServices;

#pragma warning disable 0618

public class BakeCurvatureWindow : EditorWindow 
{
    Mesh mesh;

    [MenuItem("Window/BakeCurvatureWindow")]
    private static void ShowWindow() {
        var window = GetWindow<BakeCurvatureWindow>();
        window.titleContent = new GUIContent("BakeCurvatureWindow");
        window.Show();
    }

    private void OnGUI() {
        
        mesh = EditorGUILayout.ObjectField("Linear profile", mesh, typeof(Mesh), false) as Mesh;

        EditorGUILayout.Space();

        if(GUILayout.Button("Bake curvature to new mesh"))
        {
            if(mesh == null)
                Debug.Log("please set the mesh");
            else
                CreateMeanCurvatureMesh("curvature.mesh");
        }
    }

     // get two main direction and two curvature
    [DllImport("Assets/Plugins/TrimeshDll.dll", EntryPoint = "CalculateDirectionalCurvature")]
    public static extern void CalculateDirectionalCurvature(int nv,
        float[] vertices_x,
        float[] vertices_y,
        float[] vertices_z,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] dir1_x,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] dir1_y,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] dir1_z,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] dir2_x,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] dir2_y,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] dir2_z,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] curvature0,
        [Out][MarshalAs(UnmanagedType.LPArray)] float[] curvature1,
        int nf,
        int[] triangles
    );

    void proj_curv_main(Vector3 old_u, Vector3 old_v,
               float old_ku, float old_kuv, float old_kv,
                Vector3 new_u, Vector3 new_v,
               ref float new_ku, ref float new_kuv, ref float new_kv)
    {
        float u1 = Vector3.Dot(new_u, old_u);
        float v1 = Vector3.Dot(new_u, old_v);
        float u2 = Vector3.Dot(new_v, old_u);
        float v2 = Vector3.Dot(new_v, old_v);
        new_ku = old_ku * u1 * u1 + old_kuv * (2.0f * u1 * v1) + old_kv * v1 * v1;
        new_kuv = old_ku * u1 * u2 + old_kuv * (u1 * v2 + u2 * v1) + old_kv * v1 * v2;
        new_kv = old_ku * u2 * u2 + old_kuv * (2.0f * u2 * v2) + old_kv * v2 * v2;
    }

    void CreateMeanCurvatureMesh(string name)
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);

        if (path == "")
            path = "Assets";
        else if (Path.GetExtension(path) != "")
            path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");

        string assetPathAndName = AssetDatabase.GenerateUniqueAssetPath(path + "/"+name);

        Mesh newMesh = new Mesh();
        newMesh.vertices = mesh.vertices;
        newMesh.triangles = mesh.triangles;
        newMesh.normals = mesh.normals;
        newMesh.tangents = mesh.tangents;
        newMesh.normals = mesh.normals;
        newMesh.uv = mesh.uv;

        float[] curvature0 = new float[mesh.vertices.Length];
        float[] curvature1 = new float[mesh.vertices.Length];
        float[] dir1_x = new float[mesh.vertices.Length];
        float[] dir1_y = new float[mesh.vertices.Length];
        float[] dir1_z = new float[mesh.vertices.Length];
        float[] dir2_x = new float[mesh.vertices.Length];
        float[] dir2_y = new float[mesh.vertices.Length];
        float[] dir2_z = new float[mesh.vertices.Length];

        float[] vertice_x = new float[mesh.vertices.Length];
        float[] vertice_y = new float[mesh.vertices.Length];
        float[] vertice_z = new float[mesh.vertices.Length];
        Vector4[] tangents = mesh.tangents;
        Vector3[] normals = mesh.normals;
        Vector3[] binormals = new Vector3[mesh.vertices.Length];
        for (int i = 0; i < mesh.vertices.Length; i++)
        {
            vertice_x[i] = newMesh.vertices[i].x;
            vertice_y[i] = newMesh.vertices[i].y;
            vertice_z[i] = newMesh.vertices[i].z;

            binormals[i] = Vector3.Cross(normals[i], tangents[i]) * tangents[i].w;
        }

        // get main curvature
        CalculateDirectionalCurvature(mesh.vertices.Length,
         vertice_x, vertice_y, vertice_z,
         dir1_x, dir1_y, dir1_z,
         dir2_x, dir2_y, dir2_z,
         curvature0, curvature1, mesh.triangles.Length / 3, mesh.triangles);

        // transfer to tangent and binormal coord
        Color[] curvature = new Color[mesh.vertices.Length];
        for (int i = 0; i < mesh.vertices.Length; i++)
        {
            float c0 = 0, c1 = 0, c2 = 0;
            proj_curv_main(new Vector3(dir1_x[i], dir1_y[i], dir1_z[i]), new Vector3(dir2_x[i], dir2_y[i], dir2_z[i])
            , curvature0[i], 0, curvature1[i], tangents[i], binormals[i], ref c0, ref c1, ref c2);

            // 乘以0.001转换为毫米下的曲率
            curvature[i].r = c0*0.001f;
            curvature[i].g = c1*0.001f;
            curvature[i].b = c2*0.001f;
            curvature[i].a = (curvature0[i] + curvature1[i]) * 0.5f*0.001f;
        }

        newMesh.colors = curvature;

        AssetDatabase.CreateAsset(newMesh, assetPathAndName);
        AssetDatabase.Refresh();
    }
}

#pragma warning restore 0618