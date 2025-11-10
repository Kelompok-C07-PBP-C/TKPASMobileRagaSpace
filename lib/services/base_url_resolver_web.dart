String resolveBaseApiHostImpl() => Uri.base.origin.isNotEmpty ? Uri.base.origin : 'http://localhost:8000';
