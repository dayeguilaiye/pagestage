# Room opens WorkManager's generated database by reflection at process startup.
-keep class androidx.work.impl.WorkDatabase_Impl { public <init>(); }
