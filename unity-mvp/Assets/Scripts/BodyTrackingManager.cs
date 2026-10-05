using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;

[RequireComponent(typeof(ARHumanBodyManager))]
public class BodyTrackingManager : MonoBehaviour
{
    private ARHumanBodyManager _humanBodyManager;
    public Transform garmentAnchor;
    public GameObject currentGarment;

    void Awake()
    {
        _humanBodyManager = GetComponent<ARHumanBodyManager>();
    }

    void OnEnable()
    {
        _humanBodyManager.humanBodiesChanged += OnHumanBodiesChanged;
    }

    void OnDisable()
    {
        _humanBodyManager.humanBodiesChanged -= OnHumanBodiesChanged;
    }

    private void OnHumanBodiesChanged(ARHumanBodiesChangedEventArgs args)
    {
        var body = GetFirstTrackedBody(args);
        if (body == null)
        {
            currentGarment?.SetActive(false);
            return;
        }

        var pose = body.pose;
        AlignGarmentToBody(pose);
        currentGarment?.SetActive(true);
    }

    private ARHumanBody GetFirstTrackedBody(ARHumanBodiesChangedEventArgs args)
    {
        if (args.added.Count > 0)
            return args.added[0];
        if (args.updated.Count > 0)
            return args.updated[0];
        return null;
    }

    private void AlignGarmentToBody(Pose bodyPose)
    {
        if (garmentAnchor == null || currentGarment == null)
            return;

        garmentAnchor.position = bodyPose.position;
        garmentAnchor.rotation = bodyPose.rotation;
    }

    public void SetGarment(GameObject garmentPrefab)
    {
        if (currentGarment != null)
            Destroy(currentGarment);

        if (garmentPrefab == null)
            return;

        currentGarment = Instantiate(garmentPrefab, garmentAnchor);
        currentGarment.transform.localPosition = Vector3.zero;
        currentGarment.transform.localRotation = Quaternion.identity;
        currentGarment.transform.localScale = Vector3.one * 0.85f;
    }
}
