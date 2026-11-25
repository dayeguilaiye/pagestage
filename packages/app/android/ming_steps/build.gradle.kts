plugins { id("com.android.asset-pack") }

assetPack {
    packName.set("ming_steps")
    dynamicDelivery { deliveryType.set("install-time") }
}
