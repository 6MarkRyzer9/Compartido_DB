CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Crear roles de aplicación
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user LOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_admin') THEN
        CREATE ROLE app_admin LOGIN;
    END IF;
END $$;

-- Crear tablas base con constraints mejorados
CREATE TABLE IF NOT EXISTS clientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    razon_social TEXT NOT NULL CHECK (length(trim(razon_social)) > 0),
    ruta TEXT,
    direccion TEXT,
    telefono TEXT CHECK (telefono ~ '^\+?[0-9\s-]{6,}$'),
    persona_contacto TEXT,
    documentos JSONB DEFAULT '{}'::jsonb CHECK (jsonb_typeof(documentos) = 'object'),
    folder_path TEXT,
    informes_path TEXT[] DEFAULT ARRAY[]::TEXT[],
    ultima_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT folder_path_check CHECK (folder_path ~ '^[a-zA-Z0-9_/-]+$')
);

CREATE TABLE IF NOT EXISTS personal_eddytronic (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    nombres TEXT NOT NULL,
    apellidos TEXT NOT NULL,
    ruta TEXT,
    profesion TEXT,
    cargo TEXT,
    activo BOOLEAN DEFAULT true
);

-- Modificar tabla personal_eddytronic
ALTER TABLE personal_eddytronic
ADD CONSTRAINT profesion_check CHECK (profesion IS NULL OR length(trim(profesion)) > 0),
ADD CONSTRAINT cargo_check CHECK (cargo IS NULL OR length(trim(cargo)) > 0);

CREATE TABLE IF NOT EXISTS inspeccion_visual_dimensional (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    cliente_id UUID REFERENCES clientes(id),
    inspector_id UUID REFERENCES personal_eddytronic(id),
    fecha_inspeccion TIMESTAMP WITH TIME ZONE,
    estado TEXT DEFAULT 'pendiente',
    archivo_path TEXT,
    fecha_generacion TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS muestreo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    cliente_id UUID REFERENCES clientes(id),
    inspector_id UUID REFERENCES personal_eddytronic(id),
    fecha_muestreo TIMESTAMP WITH TIME ZONE,
    estado TEXT DEFAULT 'pendiente',
    archivo_path TEXT,
    fecha_generacion TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Agregar constraint faltante para estado
ALTER TABLE inspeccion_visual_dimensional
ADD CONSTRAINT estado_valido CHECK (estado IN ('pendiente', 'generado', 'error', 'completado'));

ALTER TABLE muestreo
ADD CONSTRAINT estado_valido CHECK (estado IN ('pendiente', 'generado', 'error', 'completado'));

-- Agregar índices y constraints para relaciones
ALTER TABLE inspeccion_visual_dimensional
    ADD CONSTRAINT fk_inspeccion_cliente 
    FOREIGN KEY (cliente_id) 
    REFERENCES clientes(id) 
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
    ADD CONSTRAINT fk_inspeccion_inspector
    FOREIGN KEY (inspector_id) 
    REFERENCES personal_eddytronic(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

ALTER TABLE muestreo
    ADD CONSTRAINT fk_muestreo_cliente 
    FOREIGN KEY (cliente_id) 
    REFERENCES clientes(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
    ADD CONSTRAINT fk_muestreo_inspector
    FOREIGN KEY (inspector_id) 
    REFERENCES personal_eddytronic(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

-- Agregar tabla de logs después de las tablas principales
CREATE TABLE IF NOT EXISTS log_cambios_estado (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tabla TEXT NOT NULL,
    registro_id UUID NOT NULL,
    estado_anterior TEXT,
    estado_nuevo TEXT NOT NULL
);

-- Crear índices optimizados
CREATE INDEX idx_clientes_folder ON clientes(folder_path);
CREATE INDEX idx_clientes_ultima_actualizacion ON clientes(ultima_actualizacion);
CREATE INDEX idx_inspeccion_estado ON inspeccion_visual_dimensional(estado);
CREATE INDEX idx_muestreo_estado ON muestreo(estado);
CREATE INDEX idx_inspeccion_cliente ON inspeccion_visual_dimensional(cliente_id);
CREATE INDEX idx_muestreo_cliente ON muestreo(cliente_id);
CREATE INDEX idx_personal_activo ON personal_eddytronic(activo);

-- Crear índice para la tabla de logs
CREATE INDEX idx_log_cambios_registro ON log_cambios_estado(registro_id);
CREATE INDEX idx_log_cambios_fecha ON log_cambios_estado(created_at DESC);

-- Agregar índices para mejor performance
CREATE INDEX idx_inspeccion_cliente_id ON inspeccion_visual_dimensional(cliente_id);
CREATE INDEX idx_inspeccion_inspector_id ON inspeccion_visual_dimensional(inspector_id);
CREATE INDEX idx_muestreo_cliente_id ON muestreo(cliente_id);
CREATE INDEX idx_muestreo_inspector_id ON muestreo(inspector_id);

-- Permisos básicos
-- GRANT SELECT, INSERT, UPDATE ON clientes TO app_user;