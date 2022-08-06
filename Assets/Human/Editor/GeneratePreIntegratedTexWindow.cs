using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using System.IO;

// ref
// https://wingstone.github.io/posts/2020-09-28-preintegrated-subsurface-scattering/
// https://github.com/pieroaccardi/Unity_SphericalHarmonics_Tools

#pragma warning disable 0618

public class GeneratePreIntegratedTexWindow : EditorWindow
{

    Texture2D linearProfile;
    Texture2D skinLut;
    Material profileDisplayMat;
    float profileDisplayRange = 5;

    [MenuItem("Window/GeneratePreIntegratedTexWindow")]
    private static void ShowWindow()
    {
        var window = GetWindow<GeneratePreIntegratedTexWindow>();
        window.titleContent = new GUIContent("GeneratePreIntegratedTexWindow");
        window.Show();
    }

    private void OnGUI()
    {

        linearProfile = EditorGUILayout.ObjectField("Linear profile", linearProfile, typeof(Texture2D), false) as Texture2D;
        skinLut = EditorGUILayout.ObjectField("Skin Lut", skinLut, typeof(Texture2D), false) as Texture2D;

        EditorGUILayout.Space();

        if (GUILayout.Button("LinearProfile"))
        {
            CreateLinearProfile(1024, 1024, "LinearProfile.png", 2);
        }

        if (GUILayout.Button("PreintegratedLookupShadow"))
        {
            CreatePreintegratedLookupShadow(1024, 1024, "PreintegratedLookupShadow.png", 0);
        }

        if (GUILayout.Button("PreintegratedLookupSkin"))
        {
            CreatePreintegratedLookupSkin(1024, 1024, "PreintegratedLookupSkin.png", 1, false);
        }

        if (GUILayout.Button("PreintegratedLookupSkin(Linear)"))
        {
            if (linearProfile == null)
                Debug.Log("please set the linearProfile");
            else
                CreatePreintegratedLookupSkin(1024, 1024, "PreintegratedLookupSkinLinear.png", 1, true);
        }

        if (GUILayout.Button("SHProfile"))
        {
            if (skinLut == null)
                Debug.Log("please set the skinLut");
            else
                CreateSHProfile(1024, 3, "SHProfile.exr", 3);
        }

        EditorGUILayout.LabelField("Profile display");
        if (profileDisplayMat == null)
        {
            profileDisplayMat = new Material(Shader.Find("Human/ProfileDisplay"));
        }
        profileDisplayRange = EditorGUILayout.Slider(profileDisplayRange, 1.0f, 10.0f);
        profileDisplayMat.SetFloat("_Range", profileDisplayRange);
        Rect rect = EditorGUILayout.GetControlRect(GUILayout.Width(200), GUILayout.Height(200));
        rect.center = new Vector2(this.position.width / 2, rect.center.y);
        EditorGUI.DrawPreviewTexture(rect, Texture2D.whiteTexture, profileDisplayMat);
    }

    void CreatePreintegratedLookupSkin(int p_width, int p_height, string name, int pass, bool useLinearProfile)
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);

        if (path == "")
            path = "Assets";
        else if (Path.GetExtension(path) != "")
            path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");

        string assetPathAndName = AssetDatabase.GenerateUniqueAssetPath(path + "/" + name);

        Material material = new Material(Shader.Find("Human/LookupTexture"));
        if (useLinearProfile)
        {
            material.SetTexture("_Linear_Profile", linearProfile);
            material.SetInt("_Use_Linear_Profile", 1);
        }
        else
            material.SetInt("_Use_Linear_Profile", 0);

        RenderTexture rt = new RenderTexture(p_width, p_height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        Texture2D tex = new Texture2D(p_width, p_height, TextureFormat.RGBA32, true, true);
        Graphics.Blit(tex, rt, material, pass);
        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, p_width, p_height), 0, 0);
        tex.Apply();
        RenderTexture.active = null;

        byte[] pngData = tex.EncodeToPNG();
        File.WriteAllBytes(assetPathAndName, pngData);
        Object.DestroyImmediate(tex);
        Object.DestroyImmediate(material);
        Object.DestroyImmediate(rt);
        AssetDatabase.Refresh();

        TextureImporter ti = (TextureImporter)TextureImporter.GetAtPath(assetPathAndName);
        ti.textureType = TextureImporterType.Default;
        ti.textureFormat = TextureImporterFormat.RGB24;
        ti.textureCompression = TextureImporterCompression.Uncompressed;
        ti.sRGBTexture = false;
        ti.wrapMode = TextureWrapMode.Clamp;

        AssetDatabase.ImportAsset(assetPathAndName);
        AssetDatabase.Refresh();
    }

    void CreatePreintegratedLookupShadow(int p_width, int p_height, string name, int pass)
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);

        if (path == "")
            path = "Assets";
        else if (Path.GetExtension(path) != "")
            path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");

        string assetPathAndName = AssetDatabase.GenerateUniqueAssetPath(path + "/" + name);

        Material material = new Material(Shader.Find("Human/LookupTexture"));
        RenderTexture rt = new RenderTexture(p_width, p_height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        Texture2D tex = new Texture2D(p_width, p_height, TextureFormat.RGBA32, true, true);
        Graphics.Blit(tex, rt, material, pass);
        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, p_width, p_height), 0, 0);
        tex.Apply();
        RenderTexture.active = null;

        byte[] pngData = tex.EncodeToPNG();
        File.WriteAllBytes(assetPathAndName, pngData);
        Object.DestroyImmediate(tex);
        Object.DestroyImmediate(material);
        Object.DestroyImmediate(rt);
        AssetDatabase.Refresh();

        TextureImporter ti = (TextureImporter)TextureImporter.GetAtPath(assetPathAndName);
        ti.textureType = TextureImporterType.Default;
        ti.textureFormat = TextureImporterFormat.RGB24;
        ti.textureCompression = TextureImporterCompression.Uncompressed;
        ti.sRGBTexture = false;
        ti.wrapMode = TextureWrapMode.Clamp;

        AssetDatabase.ImportAsset(assetPathAndName);
        AssetDatabase.Refresh();
    }

    void CreateLinearProfile(int p_width, int p_height, string name, int pass)
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);

        if (path == "")
            path = "Assets";
        else if (Path.GetExtension(path) != "")
            path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");

        string assetPathAndName = AssetDatabase.GenerateUniqueAssetPath(path + "/" + name);

        Material material = new Material(Shader.Find("Human/LookupTexture"));
        RenderTexture rt = new RenderTexture(p_width, p_height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        Texture2D tex = new Texture2D(p_width, p_height, TextureFormat.RGBA32, true, true);
        Graphics.Blit(tex, rt, material, pass);
        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, p_width, p_height), 0, 0);
        tex.Apply();
        RenderTexture.active = null;

        byte[] pngData = tex.EncodeToPNG();
        File.WriteAllBytes(assetPathAndName, pngData);
        Object.DestroyImmediate(tex);
        Object.DestroyImmediate(material);
        Object.DestroyImmediate(rt);
        AssetDatabase.Refresh();

        TextureImporter ti = (TextureImporter)TextureImporter.GetAtPath(assetPathAndName);
        ti.textureType = TextureImporterType.Default;
        ti.textureFormat = TextureImporterFormat.RGB24;
        ti.textureCompression = TextureImporterCompression.Uncompressed;
        ti.sRGBTexture = false;
        ti.wrapMode = TextureWrapMode.Clamp;

        AssetDatabase.ImportAsset(assetPathAndName);
        AssetDatabase.Refresh();
    }

    void CreateSHProfile(int p_width, int p_height, string name, int pass)
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);

        if (path == "")
            path = "Assets";
        else if (Path.GetExtension(path) != "")
            path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");

        string assetPathAndName = AssetDatabase.GenerateUniqueAssetPath(path + "/" + name);

        Material material = new Material(Shader.Find("Human/LookupTexture"));
        material.SetTexture("_SkinLut", skinLut);

        RenderTexture rt = new RenderTexture(p_width, p_height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        Texture2D tex = new Texture2D(p_width, p_height, TextureFormat.RGBAHalf, true, true);
        Graphics.Blit(tex, rt, material, pass);
        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, p_width, p_height), 0, 0);
        tex.Apply();
        RenderTexture.active = null;

        byte[] pngData = tex.EncodeToEXR();
        File.WriteAllBytes(assetPathAndName, pngData);
        Object.DestroyImmediate(tex);
        Object.DestroyImmediate(material);
        Object.DestroyImmediate(rt);
        AssetDatabase.Refresh();

        TextureImporter ti = (TextureImporter)TextureImporter.GetAtPath(assetPathAndName);
        ti.textureType = TextureImporterType.Default;
        ti.textureFormat = TextureImporterFormat.RGBAHalf;
        ti.textureCompression = TextureImporterCompression.Uncompressed;
        ti.sRGBTexture = false;
        ti.wrapMode = TextureWrapMode.Clamp;
        ti.npotScale = TextureImporterNPOTScale.None;

        AssetDatabase.ImportAsset(assetPathAndName);
        AssetDatabase.Refresh();
    }
}

#pragma warning restore 0618