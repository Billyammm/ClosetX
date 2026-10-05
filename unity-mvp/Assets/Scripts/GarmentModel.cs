using UnityEngine;

[CreateAssetMenu(fileName = "GarmentModel", menuName = "AR Clothing/Garment Model")]
public class GarmentModel : ScriptableObject
{
    public string garmentId;
    public string displayName;
    public string category;
    public string description;
    public Color accentColor = Color.white;
    public GameObject garmentPrefab;
}
