// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.googlemaps;

import java.util.List;

import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Polygon;

/** Controller of a single Polygon on the map. */
class PolygonController implements PolygonOptionsSink {
  private final Polygon polygon;
  private final OnPolygonTappedListener onTappedListener;

  PolygonController(Polygon polygon, OnPolygonTappedListener onTappedListener) {
    this.polygon = polygon;
    this.onTappedListener = onTappedListener;
  }

  void onTap() {
    if (onTappedListener != null) {
      onTappedListener.onPolygonTapped(polygon);
    }
  }

  @Override
  public void setClickable(boolean clickable) {
    polygon.setClickable(clickable);
  }

  @Override
  public void setFillColor(int color) {
    polygon.setFillColor(color);
  }

  @Override
  public void setPoints(List<LatLng> points) {
    polygon.setPoints(points);
  }

  @Override
  public void setStrokeColor(int color) {
    polygon.setStrokeColor(color);
  }
}
