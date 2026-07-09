using UnityEngine;
using UnityEngine.UI;

[DisallowMultipleComponent]
public sealed class AdaptiveGridCellSizer : MonoBehaviour
{
    RectTransform _rectTransform;
    GridLayoutGroup _grid;

    [SerializeField]
    int _columns = 1;

    [SerializeField]
    float _cellHeight = 44f;

    [SerializeField]
    float _minimumCellWidth = 1f;

    bool _configured;

    public void Configure(int columns, float cellHeight, float minimumCellWidth = 1f)
    {
        _columns = Mathf.Max(1, columns);
        _cellHeight = Mathf.Max(1f, cellHeight);
        _minimumCellWidth = Mathf.Max(1f, minimumCellWidth);
        _configured = true;
        Apply();
    }

    void Awake()
    {
        Cache();
    }

    void OnRectTransformDimensionsChange()
    {
        if (_configured)
            Apply();
    }

    void Cache()
    {
        if (_rectTransform == null)
            _rectTransform = transform as RectTransform;
        if (_grid == null)
            _grid = GetComponent<GridLayoutGroup>();
    }

    void Apply()
    {
        Cache();
        if (!_configured || _rectTransform == null || _grid == null)
            return;

        float availableWidth = _rectTransform.rect.width
            - _grid.padding.left
            - _grid.padding.right
            - _grid.spacing.x * Mathf.Max(0, _columns - 1);
        float cellWidth = Mathf.Max(_minimumCellWidth, Mathf.Floor(availableWidth / _columns));
        Vector2 targetSize = new Vector2(cellWidth, _cellHeight);
        if ((_grid.cellSize - targetSize).sqrMagnitude > 0.25f)
            _grid.cellSize = targetSize;
    }
}
