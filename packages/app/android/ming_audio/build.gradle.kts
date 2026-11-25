plugins { id("com.android.asset-pack") }

assetPack {
    packName.set("ming_audio")
    dynamicDelivery { deliveryType.set("install-time") }
}
