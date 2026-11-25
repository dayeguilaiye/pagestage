plugins { id("com.android.asset-pack") }

assetPack {
    packName.set("ming_front")
    dynamicDelivery { deliveryType.set("install-time") }
}
