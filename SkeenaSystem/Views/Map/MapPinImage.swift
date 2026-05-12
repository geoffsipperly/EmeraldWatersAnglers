// Bend Fly Shop

import UIKit

/// Generates a programmatic teardrop map pin image for use with Mapbox PointAnnotation.
/// Mapbox v11 requires an explicit image (no default marker like MapKit's MKMarkerAnnotationView).
enum MapPinImage {

  /// Returns a 30×40pt teardrop pin image filled with the given color.
  /// The image is registered once with Mapbox's annotation manager via the `name` parameter
  /// on `PointAnnotation.image(image:name:)`, so it is shared across all annotations via GPU texture.
  static func pin(color: UIColor = .systemBlue) -> UIImage {
    let size = CGSize(width: 30, height: 40)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      let path = UIBezierPath()
      let center = CGPoint(x: size.width / 2, y: 12)

      // Circle head
      path.addArc(
        withCenter: center, radius: 10,
        startAngle: .pi, endAngle: 0, clockwise: true
      )
      // Teardrop point
      path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
      path.addLine(to: CGPoint(x: size.width / 2 - 10, y: 12))
      path.close()

      color.setFill()
      path.fill()

      // White inner circle
      let dot = UIBezierPath(
        arcCenter: center, radius: 4,
        startAngle: 0, endAngle: .pi * 2, clockwise: true
      )
      UIColor.brandTextPrimary.setFill()
      dot.fill()
    }
  }

  /// Hollow ("pending upload") variant of `pin(color:)`. Same teardrop
  /// silhouette but stroked instead of filled, with a transparent centre so
  /// the user can visually tell uploaded pins (filled) from locally-saved
  /// ones that still need a network. The stroke is drawn in the supplied
  /// color so each pin type keeps its color encoding.
  static func hollowPin(color: UIColor = .systemBlue) -> UIImage {
    let size = CGSize(width: 30, height: 40)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      let lineWidth: CGFloat = 2.5
      let path = UIBezierPath()
      let center = CGPoint(x: size.width / 2, y: 12)
      // Same teardrop silhouette as `pin()` for shape consistency.
      path.addArc(
        withCenter: center, radius: 10,
        startAngle: .pi, endAngle: 0, clockwise: true
      )
      path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
      path.addLine(to: CGPoint(x: size.width / 2 - 10, y: 12))
      path.close()
      path.lineWidth = lineWidth
      color.setStroke()
      path.stroke()
      // No centre dot — the open silhouette is the "pending" cue.
    }
  }
}
