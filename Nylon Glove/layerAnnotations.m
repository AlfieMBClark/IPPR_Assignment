function combined = layerAnnotations(combined, original, annotated)
    diffMask  = any(annotated ~= original, 3);
    diffMask3 = repmat(diffMask, [1, 1, 3]);
    combined(diffMask3) = annotated(diffMask3);
end