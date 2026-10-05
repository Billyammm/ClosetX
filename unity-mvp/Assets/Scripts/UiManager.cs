using UnityEngine;
using UnityEngine.UI;

public class UiManager : MonoBehaviour
{
    public BodyTrackingManager bodyTrackingManager;
    public Button tshirtButton;
    public Button hoodieButton;
    public Button shoesButton;
    public Text statusLabel;
    public GarmentModel tshirtModel;
    public GarmentModel hoodieModel;
    public GarmentModel shoesModel;

    void Start()
    {
        tshirtButton.onClick.AddListener(() => SelectGarment(tshirtModel));
        hoodieButton.onClick.AddListener(() => SelectGarment(hoodieModel));
        shoesButton.onClick.AddListener(() => SelectGarment(shoesModel));
        UpdateStatus("Choose a garment to try on.");
    }

    public void SelectGarment(GarmentModel garment)
    {
        if (garment == null || garment.garmentPrefab == null)
        {
            UpdateStatus("Garment or prefab is missing.");
            return;
        }

        bodyTrackingManager.SetGarment(garment.garmentPrefab);
        UpdateStatus($"Selected {garment.displayName}.");
    }

    private void UpdateStatus(string message)
    {
        if (statusLabel != null)
            statusLabel.text = message;
    }
}
